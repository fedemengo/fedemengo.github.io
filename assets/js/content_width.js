const CONTENT_WIDTH_KEY = "content_width";
const CONTENT_WIDTH_NARROW = "800px";
const CONTENT_WIDTH_WIDE = "960px";
const CONTENT_WIDTH_EXPANDED = "1120px";
const CONTENT_WIDTH_MODES = ["narrow", "wide", "expanded"];

let applyContentWidth = (widthMode) => {
  if (!CONTENT_WIDTH_MODES.includes(widthMode)) {
    widthMode = "narrow";
  }

  if (widthMode === "expanded") {
    document.documentElement.style.setProperty("--reader-content-width", CONTENT_WIDTH_EXPANDED);
  } else if (widthMode === "wide") {
    document.documentElement.style.setProperty("--reader-content-width", CONTENT_WIDTH_WIDE);
  } else {
    document.documentElement.style.setProperty("--reader-content-width", CONTENT_WIDTH_NARROW);
  }
  document.documentElement.setAttribute("data-content-width", widthMode);

  const widthToggle = document.getElementById("width-toggle");
  if (widthToggle) {
    const nextMode = getNextContentWidthMode(widthMode);
    widthToggle.setAttribute("aria-pressed", (widthMode !== "narrow").toString());
    widthToggle.title = `Use ${getContentWidthLabel(nextMode)} content width`;
  }
};

let getNextContentWidthMode = (widthMode) => {
  const currentIndex = CONTENT_WIDTH_MODES.indexOf(widthMode);
  return CONTENT_WIDTH_MODES[(currentIndex + 1) % CONTENT_WIDTH_MODES.length];
};

let getContentWidthLabel = (widthMode) => {
  if (widthMode === "expanded") {
    return CONTENT_WIDTH_EXPANDED;
  }
  if (widthMode === "wide") {
    return CONTENT_WIDTH_WIDE;
  }
  return CONTENT_WIDTH_NARROW;
};

let toggleContentWidth = () => {
  const currentMode = document.documentElement.getAttribute("data-content-width") || "narrow";
  const nextMode = getNextContentWidthMode(currentMode);
  localStorage.setItem(CONTENT_WIDTH_KEY, nextMode);
  applyContentWidth(nextMode);
};

applyContentWidth(localStorage.getItem(CONTENT_WIDTH_KEY));

document.addEventListener("DOMContentLoaded", function() {
  const widthToggle = document.getElementById("width-toggle");

  if (widthToggle) {
    applyContentWidth(localStorage.getItem(CONTENT_WIDTH_KEY));
    widthToggle.addEventListener("click", toggleContentWidth);
  }
});
