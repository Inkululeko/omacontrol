.pragma library

// Geometry for the arrangement canvas. Pure functions, no QML, because the
// interesting part here is arithmetic and arithmetic is worth being able to
// read on its own.
//
// The snapping follows the approach taken by Fluffet's omarchy-advanced-displays
// (MIT): snap edges to the neighbours, push out of any overlap along the
// cheapest axis, then close whatever gap is left. The last step is the one
// that matters and the one that is easy to leave out — Hyprland will happily
// lay out two displays with a hole between them, and the cursor then cannot
// cross from one to the other.

// What Hyprland lays out is the mode divided by the scale, swapped when the
// display is turned on its side.
function logicalSize(display) {
  var scale = Number(display.scale) > 0 ? Number(display.scale) : 1
  var rotated = Number(display.transform) % 2 === 1
  var w = Math.round((rotated ? display.height : display.width) / scale)
  var h = Math.round((rotated ? display.width : display.height) / scale)
  return { w: w, h: h }
}

function bounds(rects) {
  if (!rects.length) return { x: 0, y: 0, w: 1, h: 1 }
  var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (var i = 0; i < rects.length; i++) {
    minX = Math.min(minX, rects[i].x)
    minY = Math.min(minY, rects[i].y)
    maxX = Math.max(maxX, rects[i].x + rects[i].w)
    maxY = Math.max(maxY, rects[i].y + rects[i].h)
  }
  return { x: minX, y: minY, w: maxX - minX, h: maxY - minY }
}

function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

function projectionsOverlap(a, b) {
  return {
    x: a.x < b.x + b.w && b.x < a.x + a.w,
    y: a.y < b.y + b.h && b.y < a.y + a.h
  }
}

function touches(a, b) {
  var p = projectionsOverlap(a, b)
  var xTouch = a.x + a.w === b.x || b.x + b.w === a.x
  var yTouch = a.y + a.h === b.y || b.y + b.h === a.y
  return (xTouch && p.y) || (yTouch && p.x)
}

function nearest(value, candidates, threshold) {
  var best = value
  var bestDistance = threshold
  for (var i = 0; i < candidates.length; i++) {
    var distance = Math.abs(candidates[i] - value)
    if (distance < bestDistance) { best = candidates[i]; bestDistance = distance }
  }
  return best
}

function cheapest(moves, from) {
  var best = null
  for (var i = 0; i < moves.length; i++) {
    var cost = Math.abs(moves[i].x - from.x) + Math.abs(moves[i].y - from.y)
    if (!best || cost < best.cost) best = { x: moves[i].x, y: moves[i].y, cost: cost }
  }
  return best
}

// The cheapest move that puts rect against other, so the cursor can cross.
function closeGap(rect, other) {
  var p = projectionsOverlap(rect, other)
  var closedX = rect.x > other.x ? other.x + other.w : other.x - rect.w
  var closedY = rect.y > other.y ? other.y + other.h : other.y - rect.h
  var moves = []
  if (p.y) moves.push({ x: closedX, y: rect.y })
  if (p.x) moves.push({ x: rect.x, y: closedY })
  if (!p.x && !p.y) moves.push({ x: closedX, y: other.y }, { x: other.x, y: closedY })
  return cheapest(moves, rect)
}

function snapPosition(moving, others, threshold) {
  var xs = [], ys = []
  for (var i = 0; i < others.length; i++) {
    var o = others[i]
    xs.push(o.x + o.w, o.x - moving.w, o.x, o.x + o.w - moving.w)
    ys.push(o.y + o.h, o.y - moving.h, o.y, o.y + o.h - moving.h)
  }
  var rect = { x: nearest(moving.x, xs, threshold), y: nearest(moving.y, ys, threshold),
               w: moving.w, h: moving.h }

  // Two displays cannot share a pixel, so anything overlapping is pushed out
  // the short way. A push can land on a third display, which is why this runs
  // until nothing moves rather than once.
  for (var pass = 0; pass < 8; pass++) {
    var pushed = false
    for (var j = 0; j < others.length; j++) {
      if (!overlaps(rect, others[j])) continue
      var out = cheapest([
        { x: others[j].x + others[j].w, y: rect.y },
        { x: others[j].x - rect.w, y: rect.y },
        { x: rect.x, y: others[j].y + others[j].h },
        { x: rect.x, y: others[j].y - rect.h }
      ], rect)
      rect.x = out.x
      rect.y = out.y
      pushed = true
    }
    if (!pushed) break
  }

  var touching = false
  for (var t = 0; t < others.length; t++) if (touches(rect, others[t])) touching = true
  if (!touching && others.length) {
    var closest = null
    for (var c = 0; c < others.length; c++) {
      var candidate = closeGap(rect, others[c])
      if (!closest || candidate.cost < closest.cost) closest = candidate
    }
    rect.x = closest.x
    rect.y = closest.y
  }
  return { x: Math.round(rect.x), y: Math.round(rect.y) }
}
