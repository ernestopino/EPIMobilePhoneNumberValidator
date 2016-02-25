# EPIMobilePhoneNumberValidator

Validador de número de teléfono móvil / Mobile phone number validator

## Spanish

EPIPhoneNumberValidator es un proyecto de Xcode, escrito en Objective-C, que resuelve la problemática de validar (en el lado del cliente) un número de móvil al cual queremos enviar un SMS.

Las siguientes son algunas de las funcionalidades que incluye este ejemplo:

- Obtener lista de países (Country Code ISO 3166 & name)
- Obtener códigos telefónicos según país (E.164, The international public telecommunication numbering plan)
- Crear lista de objetos que representen países, unificando los nombres, código de país y código telefónico
- Filtrar lista de objetos país para obtener solo los países soportados por la aplicación
- Crear lista de países del selector según los países que soporta la aplicación
- Dar formato al teléfono que introduce el usuario en tiempo real según estándar E.164
- Aplicar estilo al campo que muestra el número de teléfono que está introduciendo el usuario (placeholder, active, invalid, valid)
- Validar el teléfono introducido por el usuario en tiempo real, y solo si es correcto habilitar el botón que realiza la acción

Espero que os sea útil ;)

## English

EPIPhoneNumberValidator is an Xcode project, written in Objective-C, which solves the problem of validating (client side) a cell number that we want to send an SMS.

The following are some of the features included in this example:

- Get a list of countries (Country Code ISO 3166 & name)
- Get telephone codes by country (E.164, The international public telecommunication numbering plan)
- Create list of objects representing countries, unifying the names, country code and dialing code
- Filter list of objects country for only the countries supported by the application
- Create list of countries according to the country selector that supports the application
- Format the phone number entered by the user in real time according to standard E.164
- Apply style to the field that displays the phone number you are entering the user (placeholder, active, invalid, valid)
- Validate the phone input by the user in real time, and only if it is correct enable the button that performs the action

I hope you find it useful ;)