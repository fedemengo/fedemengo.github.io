(() => {
  if (!window.Plotly) return;

  const root = document.documentElement;
  const textColor = () => getComputedStyle(root).getPropertyValue("--global-text-color").trim();
  const themedCharts = new Set();
  const observedWidths = new WeakMap();

  const resizeObserver = new ResizeObserver((entries) => {
    entries.forEach(({ target, contentRect }) => {
      if (!contentRect.width || observedWidths.get(target) === contentRect.width) return;
      observedWidths.set(target, contentRect.width);
      Plotly.Plots.resize(target);
    });
  });

  const themeObserver = new MutationObserver(() => {
    const color = textColor();
    themedCharts.forEach((chart) => Plotly.relayout(chart, { "font.color": color }));
  });
  themeObserver.observe(root, { attributes: true, attributeFilter: ["data-theme"] });

  document.querySelectorAll(".highlighter-rouge.language-plotly, pre > code.language-plotly").forEach((block) => {
    const code = block.matches("code") ? block : block.querySelector("pre > code");
    if (!code) return;

    const source = block.matches("code") ? code.parentElement : block;
    const chart = document.createElement("div");
    chart.className = "plotly-chart";

    try {
      const figure = JSON.parse(code.textContent);
      if (!Array.isArray(figure.data)) throw new Error("Expected a Plotly data array");

      const layout = Object.assign({ paper_bgcolor: "transparent", plot_bgcolor: "transparent" }, figure.layout);
      const usesThemeColor = !layout.font || !layout.font.color;
      if (usesThemeColor) layout.font = Object.assign({}, layout.font, { color: textColor() });
      const config = Object.assign({ responsive: true, displaylogo: false }, figure.config);

      source.before(chart);
      Plotly.newPlot(chart, figure.data, layout, config).then(() => {
        source.hidden = true;
        if (usesThemeColor) themedCharts.add(chart);
        resizeObserver.observe(chart);
      }).catch((error) => {
        chart.remove();
        console.warn("Could not render Plotly chart", error);
      });
    } catch (error) {
      chart.remove();
      console.warn("Could not render Plotly chart", error);
    }
  });
})();
