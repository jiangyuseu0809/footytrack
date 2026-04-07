const BASE_URL = 'https://footytrack.cn'

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
  data?: any
  noAuth?: boolean
}

function getToken(): string {
  return uni.getStorageSync('auth_token') || ''
}

export function setToken(token: string) {
  uni.setStorageSync('auth_token', token)
}

export function setUid(uid: string) {
  uni.setStorageSync('auth_uid', uid)
}

export function getUid(): string {
  return uni.getStorageSync('auth_uid') || ''
}

export function clearAuth() {
  uni.removeStorageSync('auth_token')
  uni.removeStorageSync('auth_uid')
  // Clear all user-related caches
  uni.removeStorageSync('cache_profile')
  uni.removeStorageSync('cache_profile_sessions')
  uni.removeStorageSync('cache_sessions')
  uni.removeStorageSync('cache_circles')
  uni.removeStorageSync('cache_circle_members')
  uni.removeStorageSync('selected_circle_id')
  uni.removeStorageSync('monthly_goals')
}

export function isLoggedIn(): boolean {
  return !!getToken()
}

/** Silently login via wx.login(); resolves when token is ready. */
let _loginPromise: Promise<void> | null = null
export function ensureLogin(): Promise<void> {
  if (isLoggedIn()) return Promise.resolve()
  if (_loginPromise) return _loginPromise
  _loginPromise = (async () => {
    try {
      const res = await wxLogin()
      setToken(res.token)
      setUid(res.uid)
    } catch (e) {
      console.error('Silent login failed', e)
    } finally {
      _loginPromise = null
    }
  })()
  return _loginPromise
}

function request<T = any>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', data, noAuth = false } = options
  const header: Record<string, string> = { 'Content-Type': 'application/json' }

  if (!noAuth) {
    const token = getToken()
    if (token) header['Authorization'] = `Bearer ${token}`
  }

  return new Promise((resolve, reject) => {
    uni.request({
      url: BASE_URL + endpoint,
      method,
      data,
      header,
      success(res) {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(res.data as T)
        } else if (res.statusCode === 401) {
          // Token expired — silently re-login and let the user retry
          clearAuth()
          ensureLogin().then(() => {
            uni.showToast({ title: '已自动重新登录，请重试', icon: 'none' })
          })
          reject(new Error('登录已过期'))
        } else {
          const errMsg = (res.data as any)?.error || `服务器错误(${res.statusCode})`
          reject(new Error(errMsg))
        }
      },
      fail(err) {
        reject(new Error(err.errMsg || '网络错误'))
      },
    })
  })
}

// --- Auth ---

interface AuthResponse {
  token: string
  uid: string
  isNewUser: boolean
}

/** WeChat mini-program login: get wx code → exchange for JWT */
export async function wxLogin(): Promise<AuthResponse> {
  const code = await new Promise<string>((resolve, reject) => {
    uni.login({
      provider: 'weixin',
      success: (res) => resolve(res.code),
      fail: (err) => reject(new Error(err.errMsg)),
    })
  })
  return request<AuthResponse>('/api/auth/wechat-mp', { method: 'POST', data: { code }, noAuth: true })
}

export async function loginWithPassword(username: string, password: string): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/login', { method: 'POST', data: { username, password }, noAuth: true })
}

export async function register(username: string, password: string): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/register', { method: 'POST', data: { username, password }, noAuth: true })
}

export async function sendSmsCode(phone: string): Promise<void> {
  await request('/api/auth/sms/send', { method: 'POST', data: { phone }, noAuth: true })
}

export async function verifySmsCode(phone: string, code: string): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/sms/verify', { method: 'POST', data: { phone, code }, noAuth: true })
}

// --- User Profile ---

export interface UserProfile {
  uid: string
  phone?: string
  wechatOpenId?: string
  username?: string
  nickname: string
  weightKg: number
  age: number
  avatarUrl?: string
  authProvider: string
  createdAt: number
  watchBoundAt?: number
  watchBrand?: string
  watchModel?: string
}

export async function getProfile(): Promise<UserProfile> {
  return request<UserProfile>('/api/user/profile')
}

export async function updateProfile(data: { nickname?: string; weightKg?: number; age?: number }): Promise<UserProfile> {
  return request<UserProfile>('/api/user/profile', { method: 'PUT', data })
}

export function uploadAvatar(filePath: string): Promise<{ avatarUrl: string }> {
  return new Promise((resolve, reject) => {
    // 读取文件为 ArrayBuffer 后以 raw bytes 发送
    const fs = uni.getFileSystemManager()
    fs.readFile({
      filePath,
      success(readRes) {
        uni.request({
          url: BASE_URL + '/api/user/avatar',
          method: 'PUT',
          header: {
            Authorization: `Bearer ${getToken()}`,
            'Content-Type': 'application/octet-stream',
          },
          data: readRes.data,
          success(res) {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(res.data as { avatarUrl: string })
            } else {
              reject(new Error('上传头像失败'))
            }
          },
          fail(err) { reject(new Error(err.errMsg || '上传头像失败')) },
        })
      },
      fail(err) { reject(new Error('读取头像文件失败')) },
    })
  })
}

// --- Sessions ---

export interface SessionDto {
  id: string
  startTime: number
  endTime: number
  playerWeightKg?: number
  playerAge?: number
  totalDistanceMeters?: number
  avgSpeedKmh?: number
  maxSpeedKmh?: number
  sprintCount?: number
  highIntensityDistanceMeters?: number
  avgHeartRate?: number
  maxHeartRate?: number
  caloriesBurned?: number
  slackIndex?: number
  slackLabel?: string
  coveragePercent?: number
  trackPointsData?: string
}

export async function getSessions(): Promise<{ sessions: SessionDto[] }> {
  return request('/api/sessions')
}

export async function deleteSession(id: string): Promise<void> {
  await request(`/api/sessions/${id}`, { method: 'DELETE' })
}

export async function getPlayerAnalysis(): Promise<{ type: string; description: string; strengths: string[]; advice: string }> {
  return request('/api/sessions/analysis')
}

// --- Teams ---

export interface Team {
  id: string
  name: string
  inviteCode: string
  createdBy: string
  createdAt: number
}

export interface TeamMember {
  userUid: string
  nickname: string
  role: string
  joinedAt: number
  sessionCount: number
  totalDistanceMeters: number
}

export async function getTeams(): Promise<{ teams: Team[] }> {
  return request('/api/teams')
}

export async function createTeam(name: string): Promise<Team> {
  return request<Team>('/api/teams', { method: 'POST', data: { name } })
}

export async function joinTeam(inviteCode: string): Promise<Team> {
  return request<Team>('/api/teams/join', { method: 'POST', data: { inviteCode } })
}

export async function getTeamDetail(teamId: string): Promise<{ team: Team; members: TeamMember[] }> {
  return request(`/api/teams/${teamId}`)
}

export async function leaveTeam(teamId: string): Promise<void> {
  await request(`/api/teams/${teamId}/leave`, { method: 'POST' })
}

// --- Matches ---

export interface Match {
  id: string
  creatorUid: string
  title: string
  matchDate: number
  location: string
  groups: number
  playersPerGroup: number
  groupColors: string
  status: string
  registrationCount: number
  createdAt: number
  maxPlayers?: number
  teamMode?: string
  latitude?: number
  longitude?: number
}

export interface MatchRegistration {
  userUid: string
  nickname: string
  groupColor: string
  registeredAt: number
}

export async function getMatches(): Promise<{ matches: Match[] }> {
  return request('/api/matches')
}

export async function createMatch(data: {
  title: string
  matchDate: number
  location: string
  groups: number
  playersPerGroup: number
  groupColors: string
  maxPlayers?: number
  teamMode?: string
  latitude?: number
  longitude?: number
}): Promise<Match> {
  return request<Match>('/api/matches', { method: 'POST', data })
}

export async function getMatchDetail(matchId: string): Promise<{ match: Match; registrations: MatchRegistration[]; isRegistered: boolean }> {
  return request(`/api/matches/${matchId}`)
}

export async function registerForMatch(matchId: string, groupColor: string): Promise<void> {
  await request(`/api/matches/${matchId}/register`, { method: 'POST', data: { groupColor } })
}

export async function cancelMatchRegistration(matchId: string): Promise<void> {
  await request(`/api/matches/${matchId}/cancel`, { method: 'POST' })
}

export async function deleteMatch(matchId: string): Promise<void> {
  await request(`/api/matches/${matchId}`, { method: 'DELETE' })
}

export async function getMatchRankings(matchId: string): Promise<{ caloriesRanking: any[]; distanceRanking: any[] }> {
  return request(`/api/matches/${matchId}/rankings`)
}

export async function getMatchSummary(matchId: string): Promise<{ summary: string }> {
  return request(`/api/matches/${matchId}/summary`)
}

// --- Circles ---

export interface Circle {
  id: string
  name: string
  avatarUrl?: string
  inviteCode: string
  createdBy: string
  createdAt: number
  memberCount: number
}

export interface CircleMember {
  userUid: string
  nickname: string
  avatarUrl?: string
  role: string
  joinedAt: number
  totalDistanceMeters: number
  totalCalories: number
  sprintCount: number
  totalDurationMinutes: number
}

export async function getCircles(): Promise<{ circles: Circle[] }> {
  return request('/api/circles')
}

export async function createCircle(name: string): Promise<Circle> {
  return request<Circle>('/api/circles', { method: 'POST', data: { name } })
}

export async function joinCircle(inviteCode: string): Promise<Circle> {
  return request<Circle>('/api/circles/join', { method: 'POST', data: { inviteCode } })
}

export async function getCircleDetail(circleId: string, period?: string): Promise<{ circle: Circle; members: CircleMember[] }> {
  const query = period ? `?period=${period}` : ''
  return request(`/api/circles/${circleId}${query}`)
}

export async function leaveCircle(circleId: string): Promise<void> {
  await request(`/api/circles/${circleId}/leave`, { method: 'POST' })
}

export function uploadCircleAvatar(circleId: string, filePath: string): Promise<Circle> {
  return new Promise((resolve, reject) => {
    const fs = uni.getFileSystemManager()
    fs.readFile({
      filePath,
      success(readRes) {
        uni.request({
          url: BASE_URL + `/api/circles/${circleId}/avatar`,
          method: 'PUT',
          header: {
            Authorization: `Bearer ${getToken()}`,
            'Content-Type': 'application/octet-stream',
          },
          data: readRes.data,
          success(res) {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(res.data as Circle)
            } else {
              reject(new Error('上传圈子头像失败'))
            }
          },
          fail(err) { reject(new Error(err.errMsg || '上传圈子头像失败')) },
        })
      },
      fail() { reject(new Error('读取头像文件失败')) },
    })
  })
}

// --- Badges ---

export interface Badge {
  id: string
  name: string
  description: string
  iconName: string
  criteriaType: string
  criteriaValue: number
}

export interface UserBadge {
  badge: Badge
  earnedAt: number
}

export async function getEarnedBadges(): Promise<{ allBadges: Badge[]; earnedBadges: UserBadge[] }> {
  return request('/api/badges/earned')
}

export async function checkBadges(): Promise<{ newBadges: Badge[] }> {
  return request('/api/badges/check', { method: 'POST' })
}

// --- Watch Bind ---

export async function generateBindCode(): Promise<{ code: string; expiresInSeconds: number }> {
  return request('/api/auth/bind/generate', { method: 'POST' })
}

// --- Feedback ---

export async function submitFeedback(content: string, imageUrls?: string[]): Promise<void> {
  await request('/api/feedback', { method: 'POST', data: { content, imageUrls } })
}

// --- Donation ---

export interface PaymentParams {
  timeStamp: string
  nonceStr: string
  package: string
  signType: string
  paySign: string
}

export async function createDonation(amountCents: number): Promise<PaymentParams> {
  return request<PaymentParams>('/api/donation/create', { method: 'POST', data: { amount: amountCents } })
}
