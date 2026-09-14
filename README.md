Resumen
En este trabajo se presenta el desarrollo y validación de un método alternativo para la
estimación de la densidad de fluidos basado en la medición de la orientación angular de una
cápsula flotante desbalanceada. El sistema propuesto se fundamenta en la relación entre el
equilibrio hidrostático y la orientación de un cuerpo rígido sometido a las fuerzas de empuje
y peso.
La cápsula incorpora un sensor inercial (IMU) y un sistema de adquisición basado en
un microcontrolador, que permiten estimar el ángulo de orientación a partir de técnicas de
fusión sensorial. Dicho ángulo se emplea como variable observable para inferir la densidad
mediante un proceso de calibración experimental.
El comportamiento dinámico del sistema se modela mediante un sistema de primer orden,
lo que permite caracterizar la evolución temporal de la orientación y obtener de forma
robusta el ángulo de equilibrio como parámetro del modelo ajustado. Este enfoque mejora
la estimación frente a métodos basados en promedios directos y facilita la interpretación del
proceso de medida.
El procedimiento experimental se basa en la calibración del sistema utilizando fluidos de
densidad conocida, obteniéndose una relación funcional entre densidad y ángulo de equilibrio
sin asumir a priori su forma. Los resultados muestran la viabilidad del método propuesto como
una alternativa de bajo coste, robusta y potencialmente integrable en sistemas embebidos
para la medición de densidad en condiciones cuasi-estáticas.
Palabras clave: densidad de fluidos, sensores inerciales, IMU, equilibrio hidrostático,
fusión sensorial
Abstract
This work presents the development and validation of an alternative method for fluid
density estimation based on the measurement of the angular orientation of an unbalanced
floating capsule. The proposed system relies on the relationship between hydrostatic equilibrium
and the orientation of a rigid body subjected to buoyant and gravitational forces.
The capsule integrates an inertial measurement unit (IMU) and a data acquisition system
based on a microcontroller, enabling the estimation of orientation through sensor fusion
techniques. The resulting angle is used as an observable variable to infer fluid density through
an experimental calibration process.
From a dynamic perspective, the system behavior is modeled as a first-order system,
allowing the characterization of the temporal evolution of the orientation and the robust
estimation of the equilibrium angle as a model parameter. This approach improves the estimation
compared to methods based on direct averaging and provides a clearer interpretation
of the measurement process.
The experimental procedure is based on system calibration using fluids with known density,
obtaining a functional relationship between density and equilibrium angle without assuming
a predefined form. The results demonstrate the feasibility of the proposed approach
as a low-cost, robust, and potentially embeddable solution for density measurement under
quasi-static conditions.
Keywords: fluid density, inertial sensors, IMU, hydrostatic equilibrium, sensor fusion
