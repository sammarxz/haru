import {
  Chart,
  BarController,
  BarElement,
  CategoryScale,
  LinearScale,
} from "chart.js";

Chart.register(BarController, BarElement, CategoryScale, LinearScale);

// Generates labels for the last 30 minutes in 5-min buckets
function buildEmptyBuckets() {
  const labels = [];
  const data = [];
  const now = new Date();
  // Round down to last 5-min boundary
  const base = new Date(Math.floor(now.getTime() / (5 * 60 * 1000)) * 5 * 60 * 1000);
  for (let i = 5; i >= 0; i--) {
    const t = new Date(base.getTime() - i * 5 * 60 * 1000);
    labels.push(
      `${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")}`
    );
    data.push(0);
  }
  return { labels, data };
}

function mergeRealtime(rows) {
  const { labels, data } = buildEmptyBuckets();
  for (const { bucket, count } of rows) {
    const d = new Date(bucket);
    const label = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
    const idx = labels.indexOf(label);
    if (idx !== -1) data[idx] = count;
  }
  return { labels, data };
}

const RealtimeChart = {
  mounted() {
    const raw = JSON.parse(this.el.dataset.chart || "[]");
    const { labels, data } = mergeRealtime(raw);

    const canvas = document.createElement("canvas");
    this.el.appendChild(canvas);

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            data,
            backgroundColor: "rgba(224,123,57,0.4)",
            borderColor: "rgba(224,123,57,0.8)",
            borderWidth: 1,
            borderRadius: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false }, tooltip: { enabled: false } },
        scales: {
          x: { display: false },
          y: { display: false, beginAtZero: true },
        },
        animation: false,
      },
    });

    this.handleEvent("update_realtime", ({ chart: rows }) => {
      const { labels: newLabels, data: newData } = mergeRealtime(rows);
      this.chart.data.labels = newLabels;
      this.chart.data.datasets[0].data = newData;
      this.chart.update();
    });
  },

  destroyed() {
    if (this.chart) this.chart.destroy();
  },
};

export default RealtimeChart;
