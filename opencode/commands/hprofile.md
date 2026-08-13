---
description: Chrome sampling heap profile (.heapprofile) analysis via hprof
---

Проанализируй Chrome sampling heap profile (`.heapprofile`) в папке `~/Downloads/dumps` с помощью инструмента hprof и сделай рекап по аллокациям.

Возможности инструмента (вывод hprof help):
!`hprof help`

Шаги:

1. Найди в папке `~/Downloads/dumps` самый свежий `.heapprofile` (по времени изменения) — например: `ls -t ~/Downloads/dumps/*.heapprofile | head -1`. Анализируй именно его.
2. Запусти `hprof analyze "<дамп>"` — базовый анализ.
3. Дополнительно сними ключевые инспекции:
   - `hprof list "<дамп>"` — sampled-локации, сгруппированные по file:line
   - `hprof calltree "<дамп>"` — инклюзивное дерево вызовов (сэмплы + поддеревья)
   - `hprof calltree "<дамп>" --url <substr>` — только фреймы из URL с этим подстрокой
   - `hprof flame "<дамп>"` — folded-стеки для flamegraph.pl / speedscope
   - `hprof analyze "<дамп>" --focus <re>` — pprof-style фокус только на матчащихся фреймах
   - `hprof diff "<предыдущий>" "<текущий>"` — сравнение двух профилей
4. Собери рекап: где больше всего аллокаций, какие пути вызовов самые тяжёлые, конкретные рекомендации.
