---
description: Chrome heap snapshot (.heapsnapshot) analysis via hprof
---

Проанализируй Chrome heap snapshot (`.heapsnapshot`) в папке `~/Downloads/dumps` с помощью инструмента hprof и сделай рекап по памяти.

Возможности инструмента (вывод hprof help):
!`hprof help`

Шаги:

1. Найди в папке `~/Downloads/dumps` самый свежий `.heapsnapshot` (по времени изменения) — например: `ls -t ~/Downloads/dumps/*.heapsnapshot | head -1`. Анализируй именно его.
2. Запусти `hprof analyze "<дамп>" --retained` — сводка по типам с retained-размерами.
3. Дополнительно сними ключевые инспекции:
   - `hprof inspect "<дамп>" --name <regex>` — топ инстансов по retained, чьи имена матчатся
   - `hprof find "<дамп>" --name <substr> --min-self 1048576 --top 0` — все узлы по имени с self >= 1MB
   - `hprof props "<дамп>" --index <n>` — поля узла с разрешёнными значениями
   - `hprof retainers "<дамп>" --index <n> --depth 12` — кто держит узел (owner-цепочка)
   - `hprof owners "<дамп>" --name '(object elements)' --min-self 1048576 --depth 4` — классический анализ утечек: "(object elements) grouped by owner"
4. Сравни с предыдущим дампом: найди предыдущий по времени `.heapsnapshot` и запусти `hprof diff "<предыдущий>" "<текущий>"` — где рост памяти.
5. Собери рекап: что ест память, кто держит объекты, что растёт между снятиями, конкретные рекомендации.
