# Mobilidade Urbana - Simulador M/M/c (Godot 4)

Simula uma fila M/M/c (chegadas de Poisson, atendimento exponencial, c servidores, fila única FIFO)
usando o dataset de contagem de veículos para definir a taxa de chegada.

## Como abrir

1. Instale o **Godot 4.3+** (versão padrão, não precisa de .NET).
2. Godot > *Import* > selecione `project.godot`.
3. Aperte **F5**.

## O que dá para modificar (painel esquerdo)

| Controle | Significado |
|---|---|
| **λ (veículos/min)** | Taxa média de chegada (modo manual) |
| **μ (veículos/min por servidor)** | Taxa média de atendimento de cada servidor (tempo médio = 1/μ) |
| **c (1 a 20)** | Número de servidores (faixas / cabines) |
| **Velocidade** | Segundos simulados por segundo real |
| **Seguir dataset** | λ passa a ser `Total / 15` a cada intervalo de 15 min simulados |
| **Multiplicador do λ do dataset** | Escala a demanda do dataset (ex.: 1,5 = 50% mais tráfego) |
| **Dia / intervalo** | Escolha o dia e a hora inicial (também dá para clicar no gráfico de barras) |
| **Copiar λ do intervalo** | Copia o λ do intervalo escolhido para o modo manual |
| **Carregar CSV...** | Carrega outro arquivo com as mesmas colunas |

Todos os parâmetros podem ser alterados **com a simulação rodando**.

## Como o dataset entra no modelo

- Cada linha = contagem de veículos em 15 min (96 intervalos por dia, 31 dias).
- `λ (veíc/min) = Total / 15`.
- `CarCount, BikeCount, BusCount, TruckCount` definem a **mistura** de tipos (cores) dos veículos que chegam.
- `Traffic Situation` colore as barras do gráfico do dia.
- A linha tracejada no gráfico de barras é a capacidade `c · μ · 15` (veículos por 15 min):
  barras acima dela significam ρ >= 1, ou seja, fila crescendo.
- O tempo de atendimento não vem do dataset (ele não tem essa informação); por isso μ é um parâmetro seu.

## Resultados exibidos (teoria x simulação)

Com a = λ/μ e ρ = a/c (estável se ρ < 1):

- Erlang C: `P(esperar) = [a^c / (c!(1-ρ))] / [ Σ_{k<c} a^k/k! + a^c / (c!(1-ρ)) ]`
- `Lq = P(esperar)·ρ/(1-ρ)`, `Wq = Lq/λ`, `W = Wq + 1/μ`, `L = λW`

No modo dataset o λ muda a cada 15 min, então a simulação (processo não estacionário) só converge
para a coluna teórica quando λ, μ e c ficam constantes por tempo suficiente (use o modo manual para isso).

## Estrutura

```
project.godot
main.tscn                 # cena única (a UI é criada por código)
data/dataset_mobilidade_urbana.txt   # o CSV (extensão .txt para o Godot não importá-lo como tradução)
scripts/
  main.gd                 # UI, ligação entre dataset, modelo e simulação
  mmc_model.gd            # fórmulas analíticas (Erlang C)
  mmc_simulation.gd       # simulação de eventos discretos
  traffic_dataset.gd      # leitura do CSV
  sim_view.gd             # desenho da fila e dos servidores
  line_chart.gd           # gráfico da fila no tempo
  day_chart.gd            # gráfico de barras do dia
```

## Observações

- Para **exportar** o jogo, em *Export > Resources > Filters to export non-resource files* adicione `data/*`.
- Se o modelo for instável (ρ >= 1) a interface avisa e sugere o número mínimo de servidores.
