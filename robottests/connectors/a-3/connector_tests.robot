*** Settings ***
Documentation     A-3 Integration API Tests
Library           Collections
Library           DateTime
Library           PoTLib
Library           REST         ${API_URL}

*** Variables ***
${LOCAL_TZ}                  +02:00
${TEST_ENV}                  sandbox
${API_URL}                   https://api-${TEST_ENV}.oftrust.net
${API_PATH}                  /broker/v1/fetch-data-product
${CONNECTOR_URL}             http://localhost:8080
${CONNECTOR_PATH}            /translator/v1/fetch
${APP_TOKEN}                 %{POT_APP_ACCESS_TOKEN}
${CLIENT_SECRET}             %{POT_CLIENT_SECRET}
${PRODUCT_CODE}              %{POT_PRODUCT_CODE}
&{ID1}                       siteId=RISAK  id=M.2826/TK3TE20
&{ID2}                       siteId=RISAK  id=M.2826/TK3TE21
&{ID3}                       siteId=RISAK  id=M.2826/TK4TE21
@{IDS}                       ${ID1}  ${ID2}  ${ID3}
${START_TIME}                2020-06-03T02:39:53.852Z
${END_TIME}                  2020-06-02T23:53:13.852Z
&{BROKER_BODY_PARAMETERS}    ids=@{IDS}
...                          option=history
&{BROKER_BODY}               productCode=${PRODUCT_CODE}
...                          parameters=${BROKER_BODY_PARAMETERS}

*** Keywords ***
Fetch Data Product
    [Arguments]     ${body}
    ${signature}    Calculate PoT Signature          ${body}    ${CLIENT_SECRET}
    Set Headers     {"x-pot-signature": "${signature}", "x-app-token": "${APP_TOKEN}"}
    POST            ${API_PATH}                      ${body}
    Output schema   response body

Get Body
    [Arguments]          &{kwargs}
    ${body}              Copy Dictionary      ${BROKER_BODY}    deepcopy=True
    ${now}               Get Current Date     time_zone=UTC     result_format=%Y-%m-%dT%H:%M:%S+00:00
    Set To Dictionary    ${body}              timestamp         ${now}
    Set To Dictionary    ${body}              &{kwargs}
    ${json_string}=      evaluate             json.dumps(${body})   json
    [Return]             ${body}

Fetch Data Product With Timestamp
    [Arguments]            ${increment}       ${time_zone}=UTC      ${result_format}=%Y-%m-%dT%H:%M:%S.%fZ
    ${timestamp}           Get Current Date
    ...                    time_zone=${time_zone}
    ...                    result_format=${result_format}
    ...                    increment=${increment}
    ${body}                Get Body                       timestamp=${timestamp}
    Fetch Data Product     ${body}

Fetch Data Product With Timestamp 200
    [Arguments]            ${increment}       ${time_zone}=UTC      ${result_format}=%Y-%m-%dT%H:%M:%S.%fZ
    Fetch Data Product With Timestamp         ${increment}    ${time_zone}    ${result_format}
    Integer                response status                200
    Array                  response body data items       minItems=2

Fetch Data Product With Timestamp 422
    [Arguments]            ${increment}
    Fetch Data Product With Timestamp         ${increment}
    Integer    response status                422
    Integer    response body error status     422
    String     response body error message    Request timestamp not within time frame.

*** Test Cases ***
fetch, 200
    [Tags]                bug-0001
    ${body}               Get Body
    Pop From Dictionary   ${body["parameters"]}                                   option
    Fetch Data Product    ${body}
    Integer               response status                                         200
    String                response body @context                                  https://standards.oftrust.net/v2/Context/DataProductOutput/Sensor/
    Object                response body data
    Array                 response body data sensors
    Array                 response body data sensors 0 measurements
    String                response body data sensors 0 measurements 0 @type       MeasureAirTemperatureCelsiusDegree

fetch, 200, history
    [Tags]                bug-0001
    ${body}               Get Body
    Fetch Data Product    ${body}
    Integer               response status                                         200
    String                response body @context                                  https://standards.oftrust.net/v2/Context/DataProductOutput/Sensor/
    Object                response body data
    Array                 response body data sensors
    Array                 response body data sensors 0 measurements
    String                response body data sensors 0 measurements 0 @type       MeasureAirTemperatureCelsiusDegree

fetch, 422, Missing data for timestamp required field
    [Tags]                 bug-0001
    ${body}                Get Body
    Pop From Dictionary    ${body}                              timestamp
    Fetch Data Product     ${body}
    Integer    response status                                  422
    Integer    response body error status                       422
    String     response body error message timestamp 0          Missing data for required field.

fetch, 422, Missing data for parameters required field
    [Tags]                 bug-0002
    ${body}                Get Body
    Pop From Dictionary    ${body}                              parameters
    Fetch Data Product     ${body}
    Integer    response status                                  422
    Integer    response body error status                       422
    String     response body error message parameters 0         Missing data for required field.

fetch, 422, Missing data for ids required field
    [Tags]                 bug-0003
    ${body}                Get Body
    Pop From Dictionary    ${body["parameters"]}                ids
    Fetch Data Product     ${body}
    Integer    response status                                  422
    Integer    response body error status                       422
    String     response body error message parameters.ids 0     Missing data for required field.

fetch, 200, Empty ids
    [Tags]                 bug-0004
    ${body}                Get Body
    Set To Dictionary      ${body["parameters"]}                ids=@{EMPTY}
    Fetch Data Product     ${body}
    Integer    response status                200
    String     response body @context         https://standards.oftrust.net/v2/Context/DataProductOutput/Sensor/
    Array      response body data sensors     maxItems=0
