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
    
    // Лише масив навантаження
    export let ramLoad: number[] = [];
    
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
    
    // Підготовка даних без labels
    $: data = {
        datasets: [{
            label: 'RAM Load',
            data: ramLoad,
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
        <Line {data} {options} />
    </div>
    