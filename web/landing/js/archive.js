import { t } from "./i18n.js";

// The archive's status filter. Buttons narrow the grid; ?status=coming-soon
// links straight to a filtered view and the choice is kept in the address.
export function initArchiveFilter() {
  const bar = document.querySelector("[data-archive-filter]");
  if (!bar) return;
  const cards = [...document.querySelectorAll(".archive .case-card")];
  const buttons = [...bar.querySelectorAll("[data-filter]")];
  const count = bar.querySelector("[data-archive-count]");

  function apply(status, remember) {
    if (!buttons.some((button) => button.dataset.filter === status)) status = "all";
    buttons.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.filter === status)));
    let shown = 0;
    cards.forEach((card) => {
      card.hidden = status !== "all" && card.dataset.status !== status;
      shown += card.hidden ? 0 : 1;
    });
    if (count && remember) count.textContent = t("archive.shown", "{n} case files shown").replace("{n}", String(shown));
    if (!remember) return;
    const url = new URL(location.href);
    if (status === "all") url.searchParams.delete("status");
    else url.searchParams.set("status", status);
    history.replaceState(history.state, "", url);
  }

  bar.addEventListener("click", (event) => {
    const button = event.target.closest("[data-filter]");
    if (button) apply(button.dataset.filter, true);
  });
  bar.hidden = false;
  apply(new URLSearchParams(location.search).get("status") || "all", false);
}
