# Apéndices – Scripts de procesamiento

Este directorio contiene los scripts utilizados en el TFM para captura, procesamiento, estimación, identificación y resultados.

## Estructura

1. `01_captura_datos.m`  
   Captura y almacenamiento de datos experimentales desde el sistema (IMU/ESP32).  
   **Salida esperada:** archivos crudos por ensayo (por ejemplo `.csv` o `.mat`).

2. `02_preprocesado.m`  
   Limpieza, sincronización y acondicionamiento de señales (filtrado básico, recorte de transitorios, etc.).  
   **Entrada:** datos crudos de `01_captura_datos.m`.  
   **Salida:** datos preprocesados listos para estimación.

3. `03_estimacion_orientacion.m`  
   Estimación de orientación angular mediante fusión sensorial (p. ej., filtro complementario).  
   **Entrada:** datos preprocesados.  
   **Salida:** series de \(\theta_{est}(t)\), \(\theta_{acc}(t)\), \(\omega_{gyro}(t)\).

4. `04_identificacion_dinamica.m`  
   Ajuste del modelo dinámico de primer orden alrededor del equilibrio.  
   **Entrada:** orientación estimada y ensayos de perturbación.  
   **Salida:** parámetros identificados (\(\theta_{eq}\), \(\tau\), \(K\)).

5. `05_calibracion_modelo.m`  
   Calibración de la relación densidad–orientación y selección de modelo.  
   **Entrada:** \(\theta_{eq}\) por nivel + densidades de referencia.  
   **Salida:** modelo de calibración final \(\hat{\rho}=g(\theta)\), métricas de ajuste.

6. `06_graficas_resultados.m`  
   Generación de figuras finales para memoria/presentación (curvas, barras de error, comparación de modelos).  
   **Entrada:** resultados de identificación y calibración.  
   **Salida:** figuras exportadas (ej. `.png`, `.pdf`).

---

## Orden recomendado de ejecución

`01_captura_datos` → `02_preprocesado` → `03_estimacion_orientacion` → `04_identificacion_dinamica` → `05_calibracion_modelo` → `06_graficas_resultados`

---

## Convenciones sugeridas

- Guardar datos en subcarpetas:
  - `../datos_crudos/`
  - `../datos_procesados/`
  - `../resultados/figuras/`
- Nombrado de archivos por ensayo:
  - `nivelXX_repYY.*` (ejemplo: `nivel03_rep02.csv`)
- Mantener unidades en nombres de variables cuando aplique:
  - `theta_rad`, `omega_rads`, `rho_gcm3`.

---

## Requisitos

- MATLAB (versión usada en el proyecto).
- Toolboxes necesarias (si aplica): Signal Processing / System Identification.
- Configuración de puerto/red para captura (si aplica en `01_captura_datos.m`).

---

## Nota de reproducibilidad

Para reproducir resultados del TFM:
1. Ejecutar scripts en el orden indicado.
2. Verificar rutas de entrada/salida al inicio de cada script.
3. Mantener la misma estructura de carpetas y nombres de archivos.
