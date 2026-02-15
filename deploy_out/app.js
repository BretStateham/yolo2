/* ── Quadratic Equation Visualizer ── */
(function () {
  "use strict";

  // ── DOM references ──
  const sliderA = document.getElementById("slider-a");
  const sliderB = document.getElementById("slider-b");
  const sliderC = document.getElementById("slider-c");
  const valA = document.getElementById("val-a");
  const valB = document.getElementById("val-b");
  const valC = document.getElementById("val-c");
  const resetBtn = document.getElementById("reset-btn");
  const canvas = document.getElementById("graph");
  const ctx = canvas.getContext("2d");

  const props = {
    equation: document.getElementById("prop-equation"),
    vertex: document.getElementById("prop-vertex"),
    axis: document.getElementById("prop-axis"),
    direction: document.getElementById("prop-direction"),
    disc: document.getElementById("prop-disc"),
    roots: document.getElementById("prop-roots"),
  };

  // ── Tab management with ARIA + keyboard ──
  const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
  const panels = tabs.map((t) => document.getElementById(t.getAttribute("aria-controls")));

  function activateTab(tab) {
    tabs.forEach((t, i) => {
      const selected = t === tab;
      t.setAttribute("aria-selected", selected);
      t.tabIndex = selected ? 0 : -1;
      panels[i].hidden = !selected;
      if (selected) panels[i].classList.add("active");
      else panels[i].classList.remove("active");
    });
    tab.focus();
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => activateTab(tab));
    tab.addEventListener("keydown", (e) => {
      const idx = tabs.indexOf(tab);
      let next = -1;
      if (e.key === "ArrowRight") next = (idx + 1) % tabs.length;
      else if (e.key === "ArrowLeft") next = (idx - 1 + tabs.length) % tabs.length;
      else if (e.key === "Home") next = 0;
      else if (e.key === "End") next = tabs.length - 1;
      if (next >= 0) { e.preventDefault(); activateTab(tabs[next]); }
    });
  });

  // ── Helpers ──
  const fmt = (v) => (Number.isInteger(v) ? v.toString() : parseFloat(v.toFixed(4)).toString());
  const fmtCoord = (x, y) => `(${fmt(x)},\\, ${fmt(y)})`;

  function renderKatex(el, latex, displayMode = false) {
    if (typeof katex !== "undefined") {
      katex.render(latex, el, { throwOnError: false, displayMode });
    } else {
      el.textContent = latex;
    }
  }

  function renderKatexInline(latex) {
    const span = document.createElement("span");
    renderKatex(span, latex);
    return span.outerHTML;
  }

  // Format a number for LaTeX, wrapping negatives in parens when needed
  const texNum = (v) => (v < 0 ? `(${fmt(v)})` : fmt(v));
  const texNumRaw = (v) => fmt(v);

  // ── Dark mode detection for canvas ──
  function isDark() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  // ── Core math ──
  function computeProperties(a, b, c) {
    if (a === 0) {
      // Linear fallback: y = bx + c
      const xInt = b !== 0 ? -c / b : null;
      return {
        linear: true, a, b, c,
        slope: b, yInt: c, xIntercept: xInt,
      };
    }
    const disc = b * b - 4 * a * c;
    const vx = -b / (2 * a);
    const vy = a * vx * vx + b * vx + c;
    let roots = [];
    if (disc > 0) {
      roots = [(-b + Math.sqrt(disc)) / (2 * a), (-b - Math.sqrt(disc)) / (2 * a)];
    } else if (disc === 0) {
      roots = [vx];
    }
    return {
      linear: false, a, b, c, disc,
      vx, vy, roots,
      axisOfSymmetry: vx,
      direction: a > 0 ? "Opens upward" : "Opens downward",
    };
  }

  // ── Canvas drawing ──
  function drawGraph(p) {
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    const W = rect.width;
    const H = rect.height;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const dark = isDark();
    const bgColor = dark ? "#1e293b" : "#ffffff";
    const gridColor = dark ? "#334155" : "#e5e7eb";
    const axisColor = dark ? "#94a3b8" : "#6b7280";
    const curveColor = dark ? "#818cf8" : "#4f46e5";
    const textColor = dark ? "#e2e8f0" : "#1a1a2e";

    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, W, H);

    // Coordinate system: center at canvas center, ~15 units visible each direction
    const scale = W / 30;
    const cx = W / 2, cy = H / 2;
    const toScreen = (x, y) => [cx + x * scale, cy - y * scale];
    const range = 15;

    // Grid
    ctx.strokeStyle = gridColor;
    ctx.lineWidth = 0.5;
    for (let i = -range; i <= range; i++) {
      const [sx] = toScreen(i, 0);
      ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, H); ctx.stroke();
      const [, sy] = toScreen(0, i);
      ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(W, sy); ctx.stroke();
    }

    // Axes
    ctx.strokeStyle = axisColor;
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(0, cy); ctx.lineTo(W, cy); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, H); ctx.stroke();

    // Tick labels
    ctx.fillStyle = textColor;
    ctx.font = "11px system-ui, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    for (let i = -range; i <= range; i++) {
      if (i === 0) continue;
      const [sx] = toScreen(i, 0);
      ctx.fillText(i, sx, cy + 4);
    }
    ctx.textAlign = "right";
    ctx.textBaseline = "middle";
    for (let i = -range; i <= range; i++) {
      if (i === 0) continue;
      const [, sy] = toScreen(0, i);
      ctx.fillText(i, cx - 6, sy);
    }

    // Axis labels
    ctx.fillStyle = textColor;
    ctx.font = "bold 13px system-ui, sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "bottom";
    ctx.fillText("x", W - 16, cy - 6);
    ctx.textAlign = "right";
    ctx.fillText("y", cx + 16, 16);

    // Axis of symmetry (dashed grey)
    if (!p.linear) {
      const [asx] = toScreen(p.axisOfSymmetry, 0);
      ctx.save();
      ctx.strokeStyle = dark ? "#64748b" : "#9ca3af";
      ctx.lineWidth = 1;
      ctx.setLineDash([6, 4]);
      ctx.beginPath(); ctx.moveTo(asx, 0); ctx.lineTo(asx, H); ctx.stroke();
      ctx.restore();
    }

    // Draw curve
    ctx.strokeStyle = curveColor;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    let first = true;
    for (let px = 0; px <= W; px += 1) {
      const x = (px - cx) / scale;
      const y = p.a * x * x + p.b * x + p.c;
      if (p.linear) {
        const yLin = p.b * x + p.c;
        const [, sy] = toScreen(x, yLin);
        if (first) { ctx.moveTo(px, sy); first = false; } else ctx.lineTo(px, sy);
      } else {
        const [, sy] = toScreen(x, y);
        if (sy < -500 || sy > H + 500) { first = true; continue; }
        if (first) { ctx.moveTo(px, sy); first = false; } else ctx.lineTo(px, sy);
      }
    }
    ctx.stroke();

    // Helper: draw dot with label
    function drawDot(x, y, color, label) {
      const [sx, sy] = toScreen(x, y);
      if (sx < -50 || sx > W + 50 || sy < -50 || sy > H + 50) return;
      ctx.beginPath();
      ctx.arc(sx, sy, 6, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.fill();
      ctx.strokeStyle = dark ? "#0f172a" : "#ffffff";
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.fillStyle = textColor;
      ctx.font = "bold 12px system-ui, sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "bottom";
      ctx.fillText(label, sx + 10, sy - 8);
    }

    if (p.linear) {
      // Green dot at y-intercept
      drawDot(0, p.c, "#22c55e", `(0, ${fmt(p.c)})`);
      // Blue dot at x-intercept
      if (p.xIntercept !== null) {
        drawDot(p.xIntercept, 0, "#3b82f6", `(${fmt(p.xIntercept)}, 0)`);
      }
    } else {
      // Red dot at vertex
      drawDot(p.vx, p.vy, "#ef4444", `(${fmt(p.vx)}, ${fmt(p.vy)})`);
      // Blue dots at roots
      p.roots.forEach((r) => drawDot(r, 0, "#3b82f6", `(${fmt(r)}, 0)`));
      // Green dot at y-intercept
      drawDot(0, p.c, "#22c55e", `(0, ${fmt(p.c)})`);
    }
  }

  // ── Properties panel ──
  function updateProperties(p) {
    if (p.linear) {
      renderKatex(props.equation, `y = ${texNumRaw(p.b)}x + ${texNumRaw(p.c)}`);
      props.vertex.textContent = "N/A (linear)";
      props.axis.textContent = "N/A (linear)";
      props.direction.textContent = p.b > 0 ? "Increasing" : p.b < 0 ? "Decreasing" : "Horizontal";
      props.disc.textContent = "N/A (linear)";
      if (p.xIntercept !== null) {
        renderKatex(props.roots, `x = ${texNumRaw(p.xIntercept)}`);
      } else {
        props.roots.textContent = "No x-intercept";
      }
      return;
    }
    // Equation
    let eqParts = [];
    if (p.a === 1) eqParts.push("x^2");
    else if (p.a === -1) eqParts.push("-x^2");
    else eqParts.push(`${texNumRaw(p.a)}x^2`);
    if (p.b !== 0) eqParts.push((p.b > 0 ? " + " : " - ") + (Math.abs(p.b) === 1 ? "" : fmt(Math.abs(p.b))) + "x");
    if (p.c !== 0) eqParts.push((p.c > 0 ? " + " : " - ") + fmt(Math.abs(p.c)));
    renderKatex(props.equation, `y = ${eqParts.join("")}`);

    renderKatex(props.vertex, fmtCoord(p.vx, p.vy));
    renderKatex(props.axis, `x = ${texNumRaw(p.vx)}`);
    props.direction.textContent = p.direction;
    renderKatex(props.disc, `\\Delta = ${texNumRaw(p.disc)}`);

    if (p.roots.length === 0) {
      props.roots.textContent = "No real roots";
    } else if (p.roots.length === 1) {
      renderKatex(props.roots, `x = ${texNumRaw(p.roots[0])}`);
    } else {
      renderKatex(props.roots, `x_1 = ${texNumRaw(p.roots[0])},\\; x_2 = ${texNumRaw(p.roots[1])}`);
    }
  }

  // ── Step-by-step solutions ──
  function buildSteps(p) {
    const a = p.a, b = p.b, c = p.c;
    const A = texNum(a), B = texNum(b), C = texNum(c);
    const Ar = texNumRaw(a), Br = texNumRaw(b), Cr = texNumRaw(c);

    // Y-Intercept
    let yintSteps;
    if (p.linear) {
      yintSteps = [
        `The equation is linear: ${renderKatexInline(`y = ${Br}x + ${Cr}`)}`,
        `Set ${renderKatexInline("x = 0")}:`,
        renderKatexInline(`y = ${Br}(0) + ${Cr} = ${Cr}`),
        `${renderKatexInline(`\\boxed{\\text{Y-intercept} = (0,\\, ${Cr})}`)}`,
      ];
    } else {
      yintSteps = [
        `The y-intercept occurs where ${renderKatexInline("x = 0")}.`,
        `Substitute into ${renderKatexInline(`y = ${Ar}x^2 + ${Br}x + ${Cr}`)}:`,
        renderKatexInline(`y = ${A}(0)^2 + ${B}(0) + ${C} = ${Cr}`),
        `${renderKatexInline(`\\boxed{\\text{Y-intercept} = (0,\\, ${Cr})}`)}`,
      ];
    }
    setPanel("panel-yint", yintSteps);

    if (p.linear) {
      setPanel("panel-disc", [`Not applicable for a linear equation (${renderKatexInline("a = 0")}).`]);
      setPanel("panel-axis", [`Not applicable for a linear equation.`]);
      setPanel("panel-qf", [
        `When ${renderKatexInline("a = 0")}, use the linear equation ${renderKatexInline(`y = ${Br}x + ${Cr}`)}.`,
        `Set ${renderKatexInline("y = 0")}:`,
        b !== 0
          ? renderKatexInline(`x = -\\frac{${C}}{${B}} = ${texNumRaw(-c / b)}`)
          : renderKatexInline("\\text{No solution (horizontal line)}"),
        b !== 0
          ? `${renderKatexInline(`\\boxed{x = ${texNumRaw(-c / b)}}`)}`
          : "",
      ].filter(Boolean));
      return;
    }

    // Discriminant
    const discVal = b * b - 4 * a * c;
    const discSteps = [
      `The discriminant determines the nature of the roots.`,
      `Formula: ${renderKatexInline("\\Delta = b^2 - 4ac")}`,
      `Substitute ${renderKatexInline(`a = ${Ar},\\; b = ${Br},\\; c = ${Cr}`)}:`,
      renderKatexInline(`\\Delta = ${B}^2 - 4 \\cdot ${A} \\cdot ${C}`),
      renderKatexInline(`\\Delta = ${texNumRaw(b * b)} - ${texNumRaw(4 * a * c)}`),
      `${renderKatexInline(`\\boxed{\\Delta = ${texNumRaw(discVal)}}`)}`,
      discVal > 0 ? `Since ${renderKatexInline("\\Delta > 0")}, there are **two distinct real roots**.`
        : discVal === 0 ? `Since ${renderKatexInline("\\Delta = 0")}, there is **one repeated real root**.`
        : `Since ${renderKatexInline("\\Delta < 0")}, there are **no real roots** (two complex roots).`,
    ];
    setPanel("panel-disc", discSteps);

    // Axis of Symmetry
    const axisVal = -b / (2 * a);
    const axisSteps = [
      `The axis of symmetry passes through the vertex.`,
      `Formula: ${renderKatexInline("x = -\\frac{b}{2a}")}`,
      `Substitute ${renderKatexInline(`a = ${Ar},\\; b = ${Br}`)}:`,
      renderKatexInline(`x = -\\frac{${B}}{2 \\cdot ${A}}`),
      renderKatexInline(`x = -\\frac{${Br}}{${texNumRaw(2 * a)}}`),
      `${renderKatexInline(`\\boxed{x = ${texNumRaw(axisVal)}}`)}`,
    ];
    setPanel("panel-axis", axisSteps);

    // Quadratic Formula
    let qfSteps = [
      `Use the quadratic formula to find the roots.`,
      `Formula: ${renderKatexInline("x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}")}`,
      `Substitute ${renderKatexInline(`a = ${Ar},\\; b = ${Br},\\; c = ${Cr}`)}:`,
      renderKatexInline(`x = \\frac{-${B} \\pm \\sqrt{${B}^2 - 4 \\cdot ${A} \\cdot ${C}}}{2 \\cdot ${A}}`),
      renderKatexInline(`x = \\frac{${texNumRaw(-b)} \\pm \\sqrt{${texNumRaw(discVal)}}}{${texNumRaw(2 * a)}}`),
    ];
    if (discVal > 0) {
      const sqrtDisc = Math.sqrt(discVal);
      const r1 = (-b + sqrtDisc) / (2 * a);
      const r2 = (-b - sqrtDisc) / (2 * a);
      qfSteps.push(renderKatexInline(`x = \\frac{${texNumRaw(-b)} \\pm ${fmt(sqrtDisc)}}{${texNumRaw(2 * a)}}`));
      qfSteps.push(`${renderKatexInline(`\\boxed{x_1 = ${fmt(r1)},\\quad x_2 = ${fmt(r2)}}`)}`);
    } else if (discVal === 0) {
      qfSteps.push(`${renderKatexInline(`\\boxed{x = ${texNumRaw(axisVal)}}`)}`);
    } else {
      const sqrtAbsDisc = Math.sqrt(-discVal);
      qfSteps.push(renderKatexInline(`x = \\frac{${texNumRaw(-b)} \\pm \\sqrt{${texNumRaw(discVal)}}}{${texNumRaw(2 * a)}}`));
      qfSteps.push(renderKatexInline(`x = \\frac{${texNumRaw(-b)} \\pm ${fmt(sqrtAbsDisc)}\\,i}{${texNumRaw(2 * a)}}`));
      qfSteps.push(`${renderKatexInline(`\\boxed{\\text{No real roots}}`)} — the roots are complex.`);
    }
    setPanel("panel-qf", qfSteps);
  }

  function setPanel(id, steps) {
    const panel = document.getElementById(id);
    panel.innerHTML = steps
      .map((s, i) => `<div class="step"><span class="step-num">${i + 1}.</span>${s}</div>`)
      .join("");
  }

  // ── Main update loop ──
  function update() {
    const a = parseFloat(sliderA.value);
    const b = parseFloat(sliderB.value);
    const c = parseFloat(sliderC.value);
    valA.textContent = fmt(a);
    valB.textContent = fmt(b);
    valC.textContent = fmt(c);

    const p = computeProperties(a, b, c);
    drawGraph(p);
    updateProperties(p);
    buildSteps(p);
  }

  // ── Event listeners ──
  [sliderA, sliderB, sliderC].forEach((s) => s.addEventListener("input", update));
  resetBtn.addEventListener("click", () => {
    sliderA.value = 1; sliderB.value = 0; sliderC.value = 0;
    update();
  });

  window.addEventListener("resize", update);
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", update);

  // Render header inline math once KaTeX is ready
  function renderInlineMath() {
    document.querySelectorAll(".math-inline").forEach((el) => {
      renderKatex(el, el.dataset.formula);
    });
  }

  // Init
  if (typeof katex !== "undefined") {
    update();
    renderInlineMath();
  } else {
    window.addEventListener("load", () => { update(); renderInlineMath(); });
  }
})();
