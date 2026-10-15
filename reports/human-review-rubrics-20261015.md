# Revisión humana independiente — siete rúbricas

Preparado el 15 de octubre de 2026. **No hay decisiones humanas rellenadas en este documento.** Las revisiones previas de Codex permanecen en `results/pilot-20261014-reference-v1/manual-review.json` y `results/reduced-20261014-reference-v1/manual-review.json`; este paquete no las reemplaza ni las presenta como revisión humana.

## Cómo responder

Lee cada prompt, respuesta literal y criterio. Para cada criterio, marca una decisión: `Sí`, `No` o `Dudoso`. Añade una nota breve si ayuda a explicar el juicio. No ejecutes el código de q10. Devuelve el bloque cumplimentado, por ejemplo:

```text
q08: criterio 1=Sí; criterio 2=Sí; criterio 3=Dudoso. Nota: ...
q09: criterio 1=...; criterio 2=...; criterio 3=.... Nota: ...
q10: criterio 1=...; criterio 2=...; criterio 3=.... Nota: revisión estática únicamente.
b19: criterio 1=...; criterio 2=...; criterio 3=.... Nota: ...
b20: criterio 1=...; criterio 2=...; criterio 3=.... Nota: ...
b21: criterio 1=...; criterio 2=...; criterio 3=.... Nota: ...
b22: criterio 1=...; criterio 2=...; criterio 3=.... Nota: ...
```

Al recibir tus decisiones, se guardarán en un archivo separado con tu autoría declarada, fecha de recepción y hashes que permitan verificar qué respuestas se revisaron. No se editarán las rúbricas, respuestas ni revisiones asistidas originales.

---

## q08 — resumen del horario del taller

Fuente: `benchmarks/pilot-v1.json`; respuesta: `results/pilot-20261014-reference-v1/q08-response.txt`.

**Prompt**

> Resume en español, en una sola frase de un máximo de 30 palabras: El taller del barrio abre de lunes a viernes a las ocho. Los sábados abre a las diez. Los domingos permanece cerrado. Conserva los tres datos de horario.

**Respuesta literal**

> El taller abre de lunes a viernes a las ocho, los sábados a las diez y permanece cerrado los domingos.

**SHA-256 de la respuesta:** `a038fb960a262ca4d59ab7f8fbed35a6147b0aff63e7befc67151da485da8ee7`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: ___

Rúbrica original:

1. Una sola frase en español, máximo 30 palabras.
2. Conserva lunes a viernes a las ocho.
3. Conserva sábado a las diez y domingo cerrado.

## q09 — explicación de RAM y almacenamiento

Fuente: `benchmarks/pilot-v1.json`; respuesta: `results/pilot-20261014-reference-v1/q09-response.txt`.

**Prompt**

> Explica en español la diferencia entre RAM y almacenamiento a alguien sin conocimientos técnicos. Usa exactamente dos frases y una analogía con una mesa y un armario. Máximo 60 palabras.

**Respuesta literal**

> La RAM es como tu mesa de trabajo, donde colocas los documentos que estás usando ahora mismo para acceder a ellos rápidamente. El almacenamiento funciona como el armario, guardando todo lo demás de forma segura pero más lenta hasta que decidas sacarlo a la mesa para trabajar con él.

**SHA-256 de la respuesta:** `d03c4b9ca543fe7ff52f92c48df424c67632d2e8c596da69f6096187f1b650d0`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: ___

Rúbrica original:

1. Exactamente dos frases en español y máximo 60 palabras.
2. RAM como espacio temporal de trabajo, almacenamiento como conservación de datos.
3. Analogía coherente con mesa y armario, sin decir que RAM conserva datos al apagar.

## q10 — función Python, revisión estática solamente

Fuente: `benchmarks/pilot-v1.json`; respuesta: `results/pilot-20261014-reference-v1/q10-response.txt`.

**Prompt**

> Escribe una función Python contar_positivos(valores) que devuelva cuántos elementos son mayores que cero sin modificar la lista. Devuelve solo el código, sin Markdown ni explicaciones.

**Respuesta literal**

```python
def contar_positivos(valores):
    return sum(1 for v in valores if v > 0)
```

**SHA-256 de la respuesta:** `95bcc4dc83c6d7655ddb24f9a04438069d514ae945d1b7e2a990072794301294`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: revisión estática; no ejecutar.

Rúbrica original:

1. Función con nombre y argumento pedidos, devuelve un conteo.
2. Cuenta estrictamente `> 0`, no incluye cero ni negativos.
3. No modifica entrada, código legible y sin Markdown; revisión estática, nunca ejecución.

## b19 — resumen de horarios y condiciones del museo

Fuente: `benchmarks/reduced-v1.json`; respuesta: `results/reduced-20261014-reference-v1/b19-response.txt`.

**Prompt**

> Resume en una sola frase de hasta 25 palabras: El museo abre los martes y jueves de 16 a 20. La entrada es gratuita. Hace falta reservar por teléfono. Conserva días, horario, precio y reserva.

**Respuesta literal**

> Abre martes y jueves de 16 a 20, con entrada gratuita que requiere reserva previa por teléfono.

**SHA-256 de la respuesta:** `a2e2bab5bbfb1118f61190eb01ea33a69dc06f39e6ce654184063c9325ea276d`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: ___

Rúbrica original:

1. Una sola frase en español y hasta 25 palabras.
2. Conserva martes y jueves, de 16 a 20.
3. Conserva gratuidad y reserva por teléfono sin añadir datos.

## b20 — copiar y mover archivos

Fuente: `benchmarks/reduced-v1.json`; respuesta: `results/reduced-20261014-reference-v1/b20-response.txt`.

**Prompt**

> Explica a una persona principiante la diferencia entre copiar un archivo y moverlo, en dos frases y hasta 55 palabras. Indica qué ocurre con el original en cada caso.

**Respuesta literal**

> Al copiar, creas una réplica independiente mientras el original permanece intacto en su ubicación inicial. En cambio, al mover, trasladas el archivo a un nuevo destino y el original desaparece del sitio anterior.

**SHA-256 de la respuesta:** `07f299686e0fae39b1e6b169ddee8d1f28191e9607dd6013597fe8b3b8fea46e`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: ___

Rúbrica original:

1. Dos frases en español y hasta 55 palabras.
2. Copiar conserva el original y crea otra copia.
3. Mover cambia su ubicación y no conserva el original en la ubicación anterior.

## b21 — aviso de cierre de sala

Fuente: `benchmarks/reduced-v1.json`; respuesta: `results/reduced-20261014-reference-v1/b21-response.txt`.

**Prompt**

> Escribe un aviso formal de dos frases y hasta 45 palabras: mañana la sala de lectura cerrará a las 17 por mantenimiento. Pide devolver los libros antes de esa hora. No añadas fechas, disculpas ni otras instrucciones.

**Respuesta literal**

> La sala de lectura cerrará mañana a las 17:00 horas por mantenimiento. Por favor, asegúrense de devolver sus libros antes de dicha hora para evitar inconvenientes.

**SHA-256 de la respuesta:** `def57b198822a64ef440c142d7652a0c8584180a9769267094b999149dcdb3c8`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: ___

Rúbrica original:

1. Dos frases, tono formal, hasta 45 palabras.
2. Comunica mañana, cierre a las 17 y mantenimiento.
3. Pide devolución antes de las 17 sin inventar datos ni otras instrucciones.

## b22 — interpretación de porcentaje completado

Fuente: `benchmarks/reduced-v1.json`; respuesta: `results/reduced-20261014-reference-v1/b22-response.txt`.

**Prompt**

> Un panel muestra 100 tareas: 80 completadas y 20 pendientes. Explica en una frase de hasta 30 palabras qué significa el porcentaje completado, sin afirmar cuánto tiempo falta ni si las tareas son fáciles.

**Respuesta literal**

> El ochenta por ciento indica que la mayoría del trabajo ya finalizó, dejando solo una quinta parte pendiente para completar el objetivo total del proyecto.

**SHA-256 de la respuesta:** `2ba968d21e541d3ab62c22f0b2dbb5b0cd3a2aaf7195fe4b53f01adb70cfa3b1`

Decisiones: criterio 1 ___; criterio 2 ___; criterio 3 ___. Nota: ___

Rúbrica original:

1. Una frase en español y hasta 30 palabras.
2. Identifica 80% y 80 de cada 100 tareas completadas.
3. No deduce tiempo restante ni dificultad.
