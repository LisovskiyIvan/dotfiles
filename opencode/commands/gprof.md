---
description: GPU frame analysis (SpectorJS captures) via gprof
---

Проанализируй SpectorJS capture (JSON кадра) в папке `~/Downloads/dumps` с помощью инструмента gprof и сделай рекап по GPU.

Возможности инструмента (вывод gprof --help):
!`gprof --help`

Шаги:

1. Найди в папке `~/Downloads/dumps` самый свежий capture (по времени изменения, расширения .json/.json.gz) — например: `ls -t ~/Downloads/dumps/*.json* | head -1`. Анализируй именно его.
2. Запусти `gprof analyze "<capture>"` — базовый анализ кадра.
3. Дополнительно сними ключевые инспекции:
   - `gprof textures "<capture>"` — VRAM по текстурам
   - `gprof draws "<capture>"` — самые тяжёлые draw calls по треугольникам
   - `gprof passes "<capture>"` — проходы рендера по FBO
   - `gprof shaders "<capture>"` — шейдеры и PBR-пермутации
   - `gprof glow "<capture>"` — GlowLayer и occluder waste
   - `gprof particles "<capture>"` — GPU-частицы и transform feedback
   - `gprof uploads "<capture>"` — per-frame texImage2D загрузки
   - `gprof instancing "<capture>"` — кандидаты на Thin/Hardware Instancing
   - `gprof states "<capture>"` — state thrashing и избыточные вызовы
   - `gprof buffers "<capture>"` — геометрия, bufferSubData, 32-битные индексы
   - `gprof sorting "<capture>"` — сортировка материалов/шейдеров, ping-pong
   - `gprof compression "<capture>"` — KTX2/ASTC и NPOT
   - `gprof fbos "<capture>"` — VRAM render targets
   - `gprof uniforms "<capture>"` — overhead uniforms
   - `gprof overdraw "<capture>"` — overdraw и fillrate
   - `gprof tree "<capture>"` — дерево сцены и иерархия мешей
   - `gprof lint "<capture>"` — Babylon.js линтер с TS-фиксами
   - `gprof compare "<предыдущий>" "<текущий>"` — сравнение двух захватов (before/after)
   - фильтры: `--filter <substr>`, `--fbo <FBO>`, `--top <n>` — сузить вывод
4. Собери рекап: где уходит VRAM и draw calls, главные узкие места GPU, конкретные рекомендации по оптимизации.
