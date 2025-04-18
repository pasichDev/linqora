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
    import {
     database
} from 'wailsjs/go/models';
    ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip);
    
    export let cpuMetric: database.CpuMetrics[] = []; // Отримуємо масив CpuMetric
    
    // Перетворюємо дані з cpuMetric для графіку
    let labels = [];
    let cpuLoad = [];
    let cpuTemp = [];
    
    $: {
        labels = cpuMetric.map((metric) => metric.timestamp);  // Відображаємо мітки часу (або інше поле з вашого об'єкта)
        cpuLoad = cpuMetric.map((metric) => metric.loadPercent);  // Завантаження процесора
        cpuTemp = cpuMetric.map((metric) => metric.temperature);  // Температура процесора
    }
    
    const options = {
        responsive: true,
        maintainAspectRatio: false,
        elements: {
            line: {
                borderWidth: 2,
                tension: 0.8
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
                display: false,  // Тепер відображаємо мітки по осі X
                title: {
                    display: false,
                    text: 'Time'
                }
            },
            y: {
                display: true, // Відображаємо ось Y
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
                borderColor: '#82c821', // зелений
                backgroundColor: 'rgba(130, 200, 33, 0.15)', // зелена заливка
                fill: true
            },
            {
                label: 'CPU Temp',
                data: cpuTemp,
                borderColor: '#17a9c0', // блакитний
                backgroundColor: 'rgba(50, 205, 205, 0.15)', // блакитна заливка
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
        <Line {data} {options} />
    </div>
    