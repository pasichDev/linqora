<script lang="ts">
import {
    Line
} from 'svelte-chartjs';

import {
    Chart as ChartJS,
    LineElement,
    PointElement,
    LinearScale,
    CategoryScale,
    Tooltip,
    Chart

} from 'chart.js';

import type {
    ScatterDataPoint
} from 'chart.js';
import {
    ram
} from 'wailsjs/go/models';
ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip);

export let ramMetric: ram.RAMMetrics[] = [];


let chartRef: Chart<"line", (number | ScatterDataPoint)[], unknown> | null = null;


$: metrics = [...ramMetric].reverse();


$: if (chartRef && metrics.length > 0) {
        chartRef.data.labels = metrics.map((m) => m.timestamp);
        chartRef.data.datasets[0].data = metrics.map((m) => m.loadPercent);
        chartRef.update();
    }

const options = {
    responsive: true,
    maintainAspectRatio: false,
    elements: {
        line: {
            borderWidth: 2,
            tension: 0.5
        },
        point: {
            radius: 0
        }
    },
    plugins: {
        legend: {
            display: false
        },
        tooltip: {
            enabled: true
        }
    },
    scales: {
        x: {
            display: false
        },
        y: {
            display: false,
            beginAtZero: true,
            suggestedMax: 100
        }
    }
};

// Підготовка даних без labels
$: data = {
    datasets: [{
        label: 'RAM Load',
        data: metrics.map((m) => m.loadPercent),
        borderColor: '#ff9933',
        backgroundColor: 'rgba(255, 153, 51, 0.2)',
        fill: true
    }]
};
</script>
    
    <style>
.chart-container {
    height: 60px;
}
</style>

<div class="chart-container">
    <Line bind:chart={chartRef} {data} {options} />
</div>
