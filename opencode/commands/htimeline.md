---
description: Chrome heap allocation timeline (.heaptimeline) analysis via hprof
---

Проанализируй Chrome heap allocation timeline (`.heaptimeline`) в папке `~/Downloads/dumps` с помощью инструмента hprof и сделай рекап по аллокациям во времени.

Возможности инструмента (вывод hprof help):
!`hprof help`

Шаги:

1. Найди в папке `~/Downloads/dumps` самый свежий `.heaptimeline` (по времени изменения) — например: `ls -t ~/Downloads/dumps/*.heaptimeline | head -1`. Анализируй именно его.
2. Запусти `hprof analyze "<дамп>"` — по-типовый сводка + топ имён аллокаций + топ стеков аллокаций (leaf <- caller) + профиль роста объектов за запись.
3. Дополнительно:
   - `hprof analyze "<дамп>" --filter <re>` — сузить имена и стеки до матчащихся (например: `--filter Vector3`)
   - `hprof flame "<дамп>"` — folded-стеки для flamegraph.pl / speedscope
4. Собери рекап: какие объекты аллоцируются чаще всего, из каких стеков, как растёт объём в течение записи, конкретные рекомендации.
