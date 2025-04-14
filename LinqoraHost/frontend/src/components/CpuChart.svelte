<script lang="ts">
import { Line } from 'svelte-chartjs';

import {
    Chart as ChartJS,
    LineElement,
    PointElement,
    LinearScale,
    CategoryScale,
    Tooltip
} from 'chart.js';

ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip);

export let labels = [];
export let cpuLoad = [];
export let cpuTemp = [];

const options = {
    responsive: true,
    maintainAspectRatio: false,
    elements: {
        line: {
            borderWidth: 2,
            tension: 0.5
        },
        point: {
            radius: 2
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

$: data = {
    labels,
    datasets: [{
            label: 'CPU Load',
            data: cpuLoad,
            borderColor: '#82c821', // синій
            backgroundColor: 'rgba(0, 191, 255, 0.15)', // синя заливка
            fill: true
        },
        {
            label: 'CPU Temp',
            data: cpuTemp,
            borderColor: '#17a9c0', // зелений
            backgroundColor: 'rgba(50, 205, 50, 0.15)', // зелена заливка
            fill: true
        }
    ]
};
</script>
  
  <style>
.chart-container {
    height: 60px;
}
</style>

<div class="chart-container">
    <Line {data} {options} />
</div>
