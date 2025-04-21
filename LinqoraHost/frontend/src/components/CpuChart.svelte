<script lang="ts">
    import { Line } from 'svelte-chartjs';
    import {
        Chart as ChartJS, 
        LineElement,
        PointElement,
        LinearScale,
        CategoryScale,
        Tooltip,
        Chart
    } from 'chart.js';

    import { database } from 'wailsjs/go/models';

    ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip);

    export let cpuMetric: database.CpuMetrics[] = [];

    let chartRef: Chart | null = null;

    $:  metrics = [...cpuMetric].reverse();

    // Оновлення графіку при зміні даних
    $: if (chartRef && metrics.length > 0) {
        chartRef.data.labels = metrics.map((m) => m.timestamp);
        chartRef.data.datasets[0].data = metrics.map((m) => m.loadPercent);
        chartRef.data.datasets[1].data = metrics.map((m) => m.temperature);
        chartRef.update();
    }

    const options = {
        responsive: true,
        maintainAspectRatio: false,
        elements: {
            line: {
                borderWidth: 2,
                tension: 0.3
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
                enabled: false
            }
        },
        scales: {
            x: {
                display: false,
                title: {
                    display: false,
                    text: 'Time'
                }
            },
            y: {
                display: true,
                beginAtZero: true,
                suggestedMax: 100
            }
        },
        animation: {
            duration: 100,
            easing: 'easeOutQuart'
        }
    };

    // Дані графіка
    $: data = {
        labels: metrics.map((m) => m.timestamp),
        datasets: [
            {
                label: 'CPU Load',
                data: metrics.map((m) => m.loadPercent),
                borderColor: '#82c821',
                backgroundColor: 'rgba(130, 200, 33, 0.15)',
                fill: true
            },
            {
                label: 'CPU Temp',
                data: metrics.map((m) => m.temperature),
                borderColor: '#17a9c0',
                backgroundColor: 'rgba(50, 205, 205, 0.15)',
                fill: true
            }
        ]
    };
</script>

<style>
.chart-container {
    height: 150px;
}
</style>

<div class="chart-container">
    <Line bind:chart={chartRef} {data} {options} />
</div>
