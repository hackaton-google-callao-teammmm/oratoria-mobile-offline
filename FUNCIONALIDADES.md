# OratorIA Kids — Funcionalidades

Inventario completo de lo que la app hace hoy. Todo corre **on-device y offline**,
verificado en un **Samsung A12** (Exynos 850, 3.6 GB RAM).

Leyenda: ✅ real y verificado en el A12 · 🟡 real pero pendiente de que lo pruebes
con tu voz/cara · ⚙️ interno (no visible) · 🔧 dev/oculto.

---

## 1. Recorrido de la app (navegación)

| Pantalla               | Qué hace                                                                                                                      | Estado |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------ |
| **Splash**             | Vox saluda ~1.6 s. Detrás, pre-calienta Gemma (esconde la carga en frío de ~31 s)                                             | ✅     |
| **Elegir perfil**      | Lista de perfiles locales con avatar. Botón "Nuevo"                                                                           | ✅     |
| **Crear perfil**       | Nombre + avatar (emoji). Sin login, sin correo, sin contraseña                                                                | ✅     |
| **INICIO (hub)**       | Vox, saludo por nombre ("¿Practicamos, Ana?"), botón grande Practicar, Mi progreso, badge "En tu dispositivo", toggle de tema | ✅     |
| **Elegir reto**        | 5 retos, cada uno con ícono y color por habilidad                                                                             | ✅     |
| **Sesión de práctica** | El loop completo (ver §2)                                                                                                     | ✅     |
| **Reporte**            | Estrellas + nivel + 1 fortaleza + 1 mejora + resultado del objetivo + métricas                                                | ✅     |
| **Mi progreso**        | Estrellas ganadas, número de prácticas, historial por reto                                                                    | ✅     |
| **Velocímetro**        | Benchmark de latencia de Gemma (oculto: long-press en Vox)                                                                    | 🔧     |

**Reversibilidad:** desde cualquier pantalla se vuelve atrás sin perder el perfil.

---

## 2. El loop de la sesión de práctica

Orden real de los pasos:

1. **Elegir reto** — Preséntate · Mi animal favorito · Mi gran idea · Cuenta un cuento · Práctica libre.
2. **Cuenta 3 · 2 · 1** — con animación; la cámara se inicializa aquí (el hitch queda oculto).
3. **EXPONIENDO** — el niño habla. En simultáneo:
   - 🟡 **preview de la cámara frontal** (espejado, sin texto correctivo encima)
   - ✅ **timer** en tipografía mono
   - ✅ **eq-waveform** (las barras de la marca) reaccionando a la voz
   - ✅ **La Banca** (público) reacciona a la energía de tu voz
   - ⚙️ se graba el audio (PCM 16 kHz) y se analiza el rostro (~4 fps)
4. **"¡Terminé!"** — el niño cierra.
5. **Vox piensa** — pantalla breve con el eq-waveform; detrás corren el STT, el análisis y Gemma.
6. **El público pregunta** — un personaje hace una **repregunta generada por Gemma**. El niño la responde en voz alta a la sala; un único botón **"Continuar"** (con auto-avance generoso de red de seguridad) lleva al reporte. No hay botón "Responder" falso: responder aún no está construido, así que no se promete.
7. **Reporte** — el veredicto (ver §5).

---

## 3. Las cuatro modalidades (todo on-device, offline)

| Modalidad                   | Cómo                                                           | Estado                  |
| --------------------------- | -------------------------------------------------------------- | ----------------------- |
| 🎙️ **Voz — energía**        | Micrófono → RMS → mueve a La Banca en vivo                     | ✅                      |
| 🗣️ **Voz — palabras (STT)** | sherpa-onnx **Whisper tiny español** transcribe lo que dijiste | 🟡 (probar con tu voz)  |
| 📷 **Cuerpo**               | ML Kit **Face Detection** → mirada al frente + sonrisa         | 🟡 (probar con tu cara) |
| 🧠 **Lenguaje**             | **Gemma 3 1B** genera la repregunta del público                | ✅                      |

Modelos: Gemma 3 1B q4 (529 MB) y Whisper tiny int8 (~99 MB) se cargan por
`adb push` (sideload) a `Android/data/pe.oratoria.oratoria_kids/files/` — muy
grandes para el APK. **Vosk `vosk-model-small-es-0.42`** (subtítulos en vivo,
~38 MB) en cambio va **bundleado como asset** (`assets/models/`) y se
descomprime solo (una vez) al almacenamiento de la app vía `ModelLoader` de
`vosk_flutter_2` — funciona de fábrica, sin sideload. ML Kit y el runtime de
sherpa viajan **dentro del APK**.

---

## 4. El "wow": público con IA que repregunta

- ✅ Al terminar, **Gemma escribe una repregunta corta y amable** según el **tema**
  del reto (no la transcripción, así funciona aunque el STT falle).
- ✅ Se muestra en boca de **La Banca** (el público), que aparece entusiasmado.
- ✅ Corre **offline en el A12** en ~5–9 s (en caliente), tapado por "Vox piensa".
- ⚙️ Si Gemma no está o tarda demasiado → entra un **banco de preguntas por tema**.

---

## 5. Qué mide y qué feedback da

### Voz (paraverbal)

| Señal            | Cómo                                            | Banda "bien" |
| ---------------- | ----------------------------------------------- | ------------ |
| ✅ Ritmo (WPM)   | palabras de contenido ÷ minutos                 | 110–150      |
| 🟡 Muletillas    | regex ES sobre la transcripción real            | < 2 / min    |
| ✅ Pausas largas | VAD por energía sobre el PCM (real, ya no fijo) | 0–1          |

**Honestidad de la voz:** si el STT no es confiable (falla, o Whisper "alucina"
sobre silencio con cosas como `[Música]`), el reporte **oculta** Ritmo y
Muletillas en vez de inventar un número. Si no se midieron pausas, oculta Pausas.
Whisper solo transcribe los primeros **30 s**, así que el ritmo se calcula sobre
esa ventana (una tasa válida) y el reporte lo indica con "primeros 30 s" cuando
la práctica fue más larga. Solo se muestra lo realmente medido.

### Cuerpo (cámara)

| Señal                  | Cómo                                               | Estado |
| ---------------------- | -------------------------------------------------- | ------ |
| 🟡 Miraste al público  | ángulo de cabeza al frente (proxy, no mirada real) | 🟡     |
| 🟡 Sonreíste           | `smilingProbability` de ML Kit                     | 🟡     |
| 🟡 Estuviste en cuadro | rostro detectado o no                              | 🟡     |

### El reporte

- ✅ **Estrellas (1–5) + nivel**, nunca el número 0–100 crudo.
- ✅ **UNA fortaleza + UNA mejora** (nada de listas de 10 correcciones).
- ✅ **Resultado del objetivo** del reto ("El objetivo era hablar despacio — ¡lo lograste!").
- ✅ Tono de **entrenador que cree en el niño**, jamás un "no miraste" que hunda.
- ✅ **Bento de métricas** (ritmo destacado + muletillas/pausas/mirada) en tipografía mono.
- ✅ Puede elegir una **dimensión corporal** como fortaleza/mejora cuando hay datos de cámara.

---

## 6. Persistencia (local, sin nube)

- ✅ **Perfiles** (nombre + avatar) sobreviven a cerrar y reabrir la app.
- ✅ **Resultados por perfil** (estrellas, reto, score) guardados y leídos en **Mi progreso**.
- ✅ Backend: `shared_preferences` (JSON). Sin servidor, sin cuentas, sin sincronización.
- ⚙️ El **audio y el video NUNCA se guardan** — se procesan al vuelo y se descartan.

---

## 7. UX para niños (transversal)

- ✅ **Cero texto correctivo mientras habla** — La Banca + el aro/eq son el feedback en vivo.
- ✅ **Estrellas y nivel**, no notas.
- ✅ **Perfiles locales** para tablet compartida de aula/familia (no es autenticación).
- ✅ **Botones grandes**, pocas palabras, Vox guía cada pantalla.
- ✅ **Español neutro**, vocabulario de niño.

---

## 8. La "regla de oro": nada rompe la sesión

Degradaciones diseñadas (no "por si acaso"):

| Si…                               | La app…                                                       | Estado |
| --------------------------------- | ------------------------------------------------------------- | ------ |
| No hay cámara / sin permiso       | Corre en solo-audio; el reporte no habla de cuerpo            | ✅     |
| Poca luz / no ve rostro           | No reporta cuerpo (no inventa un "no miraste")                | ✅     |
| **Gemma** tarda o no está         | "Vox piensa" tapa la espera; si excede → banco de preguntas   | ✅     |
| **STT** falla, no está, o alucina | Cae al texto de muestra y **oculta** las métricas de palabras | ✅     |
| Micrófono denegado                | La sesión sigue; La Banca queda en calma                      | ✅     |

---

## 9. Identidad visual y marca

- ✅ **Paleta "Spotlight"**: crema/negro editorial + acento **lima/oliva**, claro y oscuro.
- ✅ Tipografías **Inter** (texto) + **JetBrains Mono** (cifras/eyebrows), bundleadas offline.
- ✅ **Fondo aurora mesh** (blobs de color derivando) en las pantallas hero.
- ✅ **Glass cards** (superficie translúcida con el aurora asomando).
- ✅ **Vox** (coach) y **La Banca** (público) como personajes animados (CustomPaint).
- ✅ **eq-waveform** = el isotipo de OratorIA, usado como motivo de marca y viz de voz.
- ✅ **Ícono de la app** = la marca OratorIA (adaptativo + legacy) en el launcher.

---

## 10. Base técnica

- ✅ **100% offline / on-device** — no toca internet en ningún momento.
- ✅ Corre en **Samsung A12** (gama baja, Exynos 850, 3.6 GB).
- ✅ **Release build (AOT)** arranca en **~2.2 s**.
- ✅ **Núcleo puro Dart** (`oratoria_core`) con **48 tests** — la lógica de análisis/coach cubierta.
- ✅ `flutter analyze` limpio.
- ✅ Arquitectura de **puertos y adaptadores** (el core no sabe de Gemma/ML Kit/cámara).

---

## 11. Lo que todavía NO es 100% (honesto)

| Ítem                                                  | Estado                                                                                                                                                     |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Calidad del STT** con voz real de niño              | 🟡 probé con silencio → cae al mock; falta tu voz                                                                                                          |
| **Ratios de cámara** (mirada/sonrisa) con rostro real | 🟡 probé con la cámara al techo; falta tu cara                                                                                                             |
| **Pausas** en el reporte                              | ✅ ya se miden del audio (VAD por energía); se ocultan si el clip es dudoso                                                                                |
| **Transcripción como fallback**                       | si el STT falla/alucina, usa texto de muestra y **oculta** las métricas de palabras                                                                        |
| **RAM con las 3 modalidades juntas**                  | al borde en el A12 (available baja a ~90 MB en el pico), pero **sin matar la app**: soak de ~5-6 sesiones seguidas, pid estable, RAM se recupera a ~530 MB |
| **Confirmación offline estricta**                     | falta modo avión + instalación fresca para el 100%                                                                                                         |
| **Postura (Pose Detection)**                          | fuera de alcance (candidato a OOM); solo mirada + sonrisa                                                                                                  |
| **Subtítulos en vivo (Vosk)**                          | ✅ el modelo va bundleado como asset (ya no depende de `adb push`); falta probar el primer arranque en el A12 real, donde se descomprime una sola vez         |

---

## 12. Categorías de certificado que cubre (hackathon)

- 🏅 **Edge / On-Device** — todo local, Gemma en el equipo, sin internet.
- 🏅 **Multimodal** — voz + cuerpo + lenguaje generado.
- 🏅 **Agentes** — el público que escucha, reacciona y **repregunta** (lazo agente).
