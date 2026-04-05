import type { SessionDto } from './api'

export interface AbilityItem {
  ability: string
  value: number
}

export interface TrackPoint {
  latitude: number
  longitude: number
  speed: number
}

export function roundRect(ctx: any, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.lineTo(x + w - r, y)
  ctx.arcTo(x + w, y, x + w, y + r, r)
  ctx.lineTo(x + w, y + h - r)
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
  ctx.lineTo(x + r, y + h)
  ctx.arcTo(x, y + h, x, y + h - r, r)
  ctx.lineTo(x, y + r)
  ctx.arcTo(x, y, x + r, y, r)
  ctx.closePath()
}

export function parseTrackPoints(sessions: SessionDto[]): TrackPoint[] {
  const points: TrackPoint[] = []
  for (const s of sessions) {
    if (!s.trackPointsData) continue
    try {
      const json = decodeURIComponent(escape(atob(s.trackPointsData)))
      const arr = JSON.parse(json) as any[]
      for (const p of arr) {
        if (p.latitude && p.longitude) {
          points.push({ latitude: p.latitude, longitude: p.longitude, speed: p.speed || 0 })
        }
      }
    } catch {}
  }
  return points
}

export function computeAbilityData(sessions: SessionDto[]): AbilityItem[] {
  if (sessions.length === 0) {
    return [
      { ability: '速度', value: 0 },
      { ability: '耐力', value: 0 },
      { ability: '爆发力', value: 0 },
      { ability: '灵活性', value: 0 },
      { ability: '体能', value: 0 },
      { ability: '持久力', value: 0 },
    ]
  }
  const avgSpeed = sessions.reduce((s, v) => s + (v.avgSpeedKmh || 0), 0) / sessions.length
  const maxSpeed = Math.max(...sessions.map(s => s.maxSpeedKmh || 0))
  const avgDist = sessions.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0) / sessions.length / 1000
  const totalSprints = sessions.reduce((s, v) => s + (v.sprintCount || 0), 0)
  return [
    { ability: '速度', value: Math.min(100, Math.round(maxSpeed * 4)) },
    { ability: '耐力', value: Math.min(100, Math.round(avgDist * 15)) },
    { ability: '爆发力', value: Math.min(100, Math.round(totalSprints * 5)) },
    { ability: '灵活性', value: Math.min(100, Math.round(avgSpeed * 8)) },
    { ability: '体能', value: Math.min(100, Math.round((avgDist + avgSpeed) * 6)) },
    { ability: '持久力', value: Math.min(100, Math.round(avgDist * 12)) },
  ]
}

export function drawRadarChart(
  canvasId: string,
  data: AbilityItem[],
  callback: (tempFilePath: string) => void,
) {
  const ctx = uni.createCanvasContext(canvasId)
  const count = data.length
  if (count === 0) return

  const size = 280
  const cx = size / 2
  const cy = size / 2
  const maxR = size / 2 - 40
  const levels = 4
  const angleStep = (Math.PI * 2) / count
  const startAngle = -Math.PI / 2

  ctx.clearRect(0, 0, size, size)

  // Draw grid rings
  for (let lv = 1; lv <= levels; lv++) {
    const r = (maxR / levels) * lv
    ctx.beginPath()
    for (let i = 0; i <= count; i++) {
      const angle = startAngle + angleStep * (i % count)
      const x = cx + r * Math.cos(angle)
      const y = cy + r * Math.sin(angle)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.setStrokeStyle('rgba(255,255,255,0.08)')
    ctx.setLineWidth(1)
    ctx.stroke()
  }

  // Draw axis lines
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    ctx.beginPath()
    ctx.moveTo(cx, cy)
    ctx.lineTo(cx + maxR * Math.cos(angle), cy + maxR * Math.sin(angle))
    ctx.setStrokeStyle('rgba(255,255,255,0.06)')
    ctx.setLineWidth(1)
    ctx.stroke()
  }

  // Draw data area
  ctx.beginPath()
  for (let i = 0; i <= count; i++) {
    const idx = i % count
    const angle = startAngle + angleStep * idx
    const r = (data[idx].value / 100) * maxR
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    if (i === 0) ctx.moveTo(x, y)
    else ctx.lineTo(x, y)
  }
  ctx.closePath()
  ctx.setFillStyle('rgba(7,193,96,0.3)')
  ctx.fill()
  ctx.setStrokeStyle('#07c160')
  ctx.setLineWidth(2)
  ctx.stroke()

  // Draw data points
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const r = (data[i].value / 100) * maxR
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    ctx.beginPath()
    ctx.arc(x, y, 3, 0, Math.PI * 2)
    ctx.setFillStyle('#07c160')
    ctx.fill()
  }

  // Draw labels
  ctx.setFontSize(11)
  ctx.setTextAlign('center')
  ctx.setTextBaseline('middle')
  ctx.setFillStyle('#999999')
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const labelR = maxR + 20
    const x = cx + labelR * Math.cos(angle)
    const y = cy + labelR * Math.sin(angle)
    ctx.fillText(data[i].ability, x, y)
  }

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId,
        success: (res) => { callback(res.tempFilePath) },
        fail: (err) => { console.error('radar canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}

export interface CurvePoint {
  label: string
  value: number
}

/**
 * Draw a smooth curve chart with Catmull-Rom spline interpolation.
 * Used for heart rate and speed curves.
 */
export function drawSmoothCurveChart(
  canvasId: string,
  points: CurvePoint[],
  options: {
    color?: string
    gradientFrom?: string
    gradientTo?: string
    unit?: string
    minLabel?: string
    maxLabel?: string
  },
  callback: (tempFilePath: string) => void,
) {
  const ctx = uni.createCanvasContext(canvasId)
  const W = 350
  const H = 200
  const padLeft = 40
  const padRight = 16
  const padTop = 24
  const padBottom = 36

  const chartW = W - padLeft - padRight
  const chartH = H - padTop - padBottom

  const color = options.color || '#07c160'
  const gradFrom = options.gradientFrom || 'rgba(7,193,96,0.35)'
  const gradTo = options.gradientTo || 'rgba(7,193,96,0.02)'

  ctx.clearRect(0, 0, W, H)

  if (points.length < 2) {
    ctx.draw()
    return
  }

  const values = points.map(p => p.value)
  const minVal = Math.min(...values)
  const maxVal = Math.max(...values)
  const range = maxVal - minVal || 1
  const yPad = range * 0.1

  const toX = (i: number) => padLeft + (i / (points.length - 1)) * chartW
  const toY = (v: number) => padTop + chartH - ((v - minVal + yPad) / (range + yPad * 2)) * chartH

  // Horizontal grid lines (3 lines)
  ctx.setStrokeStyle('rgba(255,255,255,0.06)')
  ctx.setLineWidth(0.5)
  for (let i = 0; i < 3; i++) {
    const y = padTop + (chartH / 3) * (i + 0.5)
    ctx.beginPath()
    ctx.moveTo(padLeft, y)
    ctx.lineTo(W - padRight, y)
    ctx.stroke()
  }

  // Compute smooth cubic spline using monotone piecewise cubic Hermite (for reliable endpoint handling)
  const n = points.length
  const xs = Array.from({ length: n }, (_, i) => toX(i))
  const ys = values.map(v => toY(v))

  // Compute tangents (Catmull-Rom style, clamped at endpoints)
  const tangents: { dx: number; dy: number }[] = []
  for (let i = 0; i < n; i++) {
    if (i === 0) {
      tangents.push({ dx: xs[1] - xs[0], dy: ys[1] - ys[0] })
    } else if (i === n - 1) {
      tangents.push({ dx: xs[n - 1] - xs[n - 2], dy: ys[n - 1] - ys[n - 2] })
    } else {
      tangents.push({ dx: (xs[i + 1] - xs[i - 1]) * 0.5, dy: (ys[i + 1] - ys[i - 1]) * 0.5 })
    }
  }

  const spline: { x: number; y: number }[] = []
  for (let i = 0; i < n - 1; i++) {
    const x0 = xs[i], y0 = ys[i]
    const x1 = xs[i + 1], y1 = ys[i + 1]
    const m0x = tangents[i].dx, m0y = tangents[i].dy
    const m1x = tangents[i + 1].dx, m1y = tangents[i + 1].dy

    const segments = 16
    for (let t = 0; t <= segments; t++) {
      if (i > 0 && t === 0) continue // avoid duplicate junction points
      const s = t / segments
      const s2 = s * s
      const s3 = s2 * s
      const h00 = 2 * s3 - 3 * s2 + 1
      const h10 = s3 - 2 * s2 + s
      const h01 = -2 * s3 + 3 * s2
      const h11 = s3 - s2
      spline.push({
        x: h00 * x0 + h10 * m0x + h01 * x1 + h11 * m1x,
        y: h00 * y0 + h10 * m0y + h01 * y1 + h11 * m1y,
      })
    }
  }

  // Draw fill gradient
  const grd = ctx.createLinearGradient(0, padTop, 0, H - padBottom)
  grd.addColorStop(0, gradFrom)
  grd.addColorStop(1, gradTo)

  ctx.beginPath()
  ctx.moveTo(spline[0].x, H - padBottom)
  for (const pt of spline) {
    ctx.lineTo(pt.x, pt.y)
  }
  ctx.lineTo(spline[spline.length - 1].x, H - padBottom)
  ctx.closePath()
  ctx.setFillStyle(grd)
  ctx.fill()

  // Draw curve line
  ctx.beginPath()
  ctx.moveTo(spline[0].x, spline[0].y)
  for (let i = 1; i < spline.length; i++) {
    ctx.lineTo(spline[i].x, spline[i].y)
  }
  ctx.setStrokeStyle(color)
  ctx.setLineWidth(2)
  ctx.stroke()

  // Draw data points
  for (let i = 0; i < points.length; i++) {
    const x = toX(i)
    const y = toY(values[i])
    ctx.beginPath()
    ctx.arc(x, y, 3, 0, Math.PI * 2)
    ctx.setFillStyle(color)
    ctx.fill()
  }

  // X-axis labels
  ctx.setFontSize(9)
  ctx.setTextAlign('center')
  ctx.setFillStyle('#666666')
  for (let i = 0; i < points.length; i++) {
    ctx.fillText(points[i].label, toX(i), H - padBottom + 18)
  }

  // Y-axis labels (min/max)
  ctx.setFontSize(9)
  ctx.setTextAlign('right')
  ctx.setFillStyle('#666666')
  const unit = options.unit || ''
  ctx.fillText(String(Math.round(maxVal)) + unit, padLeft - 4, padTop + 4)
  ctx.fillText(String(Math.round(minVal)) + unit, padLeft - 4, H - padBottom)

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId,
        success: (res) => { callback(res.tempFilePath) },
        fail: (err) => { console.error('curve canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}

export function drawHeatmapChart(
  canvasId: string,
  points: TrackPoint[],
  callback: (tempFilePath: string) => void,
) {
  const ctx = uni.createCanvasContext(canvasId)
  const w = 350
  const h = 263 // 4:3 ratio

  ctx.clearRect(0, 0, w, h)

  // Dark green base
  ctx.setFillStyle('#0a2a0f')
  ctx.fillRect(0, 0, w, h)

  if (points.length > 0) {
    let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity
    for (const p of points) {
      if (p.latitude < minLat) minLat = p.latitude
      if (p.latitude > maxLat) maxLat = p.latitude
      if (p.longitude < minLng) minLng = p.longitude
      if (p.longitude > maxLng) maxLng = p.longitude
    }

    const latPad = Math.max((maxLat - minLat) * 0.1, 0.0002)
    const lngPad = Math.max((maxLng - minLng) * 0.1, 0.0002)
    minLat -= latPad; maxLat += latPad
    minLng -= lngPad; maxLng += lngPad

    const latRange = maxLat - minLat || 0.001
    const lngRange = maxLng - minLng || 0.001

    const maxSpeed = Math.max(...points.map(p => p.speed), 1)

    for (const p of points) {
      const x = ((p.longitude - minLng) / lngRange) * w
      const y = (1 - (p.latitude - minLat) / latRange) * h
      const intensity = Math.min(p.speed / maxSpeed, 1)
      const radius = 8 + intensity * 8

      let r: number, g: number, b: number
      if (intensity < 0.5) {
        const t = intensity * 2
        r = Math.round(22 + t * (234 - 22))
        g = Math.round(163 + t * (179 - 163))
        b = Math.round(74 - t * 74)
      } else {
        const t = (intensity - 0.5) * 2
        r = Math.round(234 + t * (239 - 234))
        g = Math.round(179 - t * (179 - 68))
        b = Math.round(0 + t * 68)
      }

      const alpha = 0.35 + intensity * 0.35
      ctx.beginPath()
      ctx.arc(x, y, radius, 0, Math.PI * 2)
      ctx.setFillStyle(`rgba(${r},${g},${b},${alpha})`)
      ctx.fill()
    }
  }

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId,
        success: (res) => { callback(res.tempFilePath) },
        fail: (err) => { console.error('heatmap canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}
