import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Filler,
  Tooltip,
} from "chart.js";

Chart.register(
  LineController,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Filler,
  Tooltip
);

const PageviewChart = {
  mounted() {
    const raw = JSON.parse(this.el.dataset.chart || "[]");
    const period = this.el.dataset.period || "today";
    const { labels, data } = parseData(raw, period);

    const canvas = document.createElement("canvas");
    this.el.appendChild(canvas);

    this.chart = new Chart(canvas, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "Pageviews",
            data,
            borderColor: "rgba(224,123,57,1)",
            backgroundColor: "rgba(224,123,57,0.10)",
            borderWidth: 2,
            tension: 0.4,
            fill: true,
            pointRadius: 0,
            pointHoverRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (item) => `${item.parsed.y} views`,
            },
          },
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { font: { size: 11 }, maxRotation: 0, maxTicksLimit: 8 },
          },
          y: {
            beginAtZero: true,
            grid: { color: "rgba(0,0,0,0.04)" },
            ticks: { font: { size: 11 }, precision: 0 },
          },
        },
      },
    });

    this.handleEvent("update_chart", ({ chart, period: newPeriod }) => {
      const { labels, data } = parseData(chart, newPeriod);
      this.chart.data.labels = labels;
      this.chart.data.datasets[0].data = data;
      this.chart.update();
    });
  },

  destroyed() {
    if (this.chart) this.chart.destroy();
  },
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function parseData(rows, period) {
  const map = buildEmptyMap(period);

  if (Array.isArray(rows)) {
    for (const { bucket, count } of rows) {
      if (!bucket) continue;
      const label = formatBucket(bucket, period);
      if (map[label] !== undefined) {
        map[label] += count;
      } else {
        map[label] = count;
      }
    }
  }

  return { labels: Object.keys(map), data: Object.values(map) };
}

function formatBucket(iso, period) {
  if (!iso) return "?";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;

  if (period === "today" || period === "yesterday") {
    return `${String(d.getUTCHours()).padStart(2, "0")}:00`;
  }
  if (period === "12m" || period === "year" || period === "all") {
    return d.toLocaleDateString("en-US", { month: "short", timeZone: "UTC" });
  }
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
}

function buildEmptyMap(period) {
  const map = {};
  const d = new Date();
  const utcNow = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  
  if (period === "today" || period === "yesterday") {
    for (let i = 0; i <= 23; i++) {
      map[`${String(i).padStart(2, '0')}:00`] = 0;
    }
  } else if (period === "week" || period === "30d" || period === "month") {
    let days = period === "30d" ? 30 : period === "month" ? new Date(utcNow.getUTCFullYear(), utcNow.getUTCMonth() + 1, 0).getUTCDate() : 7;
    let start = new Date(utcNow);
    
    if (period === "week") {
      const day = start.getUTCDay() || 7;
      start.setUTCDate(start.getUTCDate() - day + 1); // Monday
    } else if (period === "month") {
      start.setUTCDate(1);
    } else {
      start.setUTCDate(start.getUTCDate() - days + 1);
    }
    
    for (let i = 0; i < days; i++) {
      const cur = new Date(start.getTime() + i * 86400 * 1000);
      const label = cur.toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
      map[label] = 0;
    }
  } else if (period === "6m") {
    // 26 weekly buckets — find the Monday of 26 weeks ago
    const start = new Date(utcNow.getTime() - 26 * 7 * 86400 * 1000);
    const dayOfWeek = start.getUTCDay() || 7;
    start.setUTCDate(start.getUTCDate() - dayOfWeek + 1); // rewind to Monday
    for (let i = 0; i < 26; i++) {
      const cur = new Date(start.getTime() + i * 7 * 86400 * 1000);
      const label = cur.toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
      map[label] = 0;
    }
  } else if (period === "year" || period === "12m") {
    let startMonth = period === "year" ? 0 : utcNow.getUTCMonth() - 11;
    let year = utcNow.getUTCFullYear();
    for (let i = 0; i < 12; i++) {
      const cur = new Date(Date.UTC(year, startMonth + i, 1));
      const label = cur.toLocaleDateString("en-US", { month: "short", timeZone: "UTC" });
      map[label] = 0;
    }
  }
  
  return map;
}

export default PageviewChart;
