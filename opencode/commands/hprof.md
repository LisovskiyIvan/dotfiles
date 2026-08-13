---
description: Heap dump analysis (heapsnapshot/heapprofile/heaptimeline) via hprof
---

Проанализируй Chrome heap-дампы в папке `~/Downloads/dumps` с помощью инструмента hprof и сделай рекап по памяти.

Возможности инструмента (вывод hprof help):
!`hprof help`

Шаги:

1. Найди в папке `~/Downloads/dumps` самый свежий дамп (по времени изменения, расширения .heapsnapshot/.heapprofile/.heaptimeline) — например: `ls -t ~/Downloads/dumps/*.heap* | head -1`. Анализируй именно его.
2. Запусти `hprof analyze "<дамп>"` — базовый анализ (hprof сам определяет формат).
3. Дополнительно сними ключевые инспекции (если применимо к этому формату дампа):
   - `hprof analyze "<дамп>" --retained` — retained-размеры к self (для heapsnapshot)
   - `hprof calltree "<дамп>"` — инклюзивное дерево вызовов (для heapprofile)
   - `hprof flame "<дамп>"` — folded-стеки для flamegraph (для heapprofile/heaptimeline)
   - `hprof diff "<дамп1>" "<дамп2>"` — сравнение двух дампов (текущий и предыдущий)
   - `hprof analyze "<дамп>" --filter <re>` — сузить по regex (для heaptimeline)
4. Собери рекап: где уходит память, главные узкие места, конкретные рекомендации по оптимизации.
