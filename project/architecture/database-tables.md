# Таблицы БД

Полная структура (колонки, типы, ограничения) — в самих SQL-скриптах, здесь только карта.
Координаты везде — `POINT SRID 4326`, в WKT порядок «широта долгота».

## Адреса — `init/01_0x_schema_*.sql`, по файлу на таблицу

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `countries` | [01_01_schema_countries.sql](../../veze-node-app/init/01_01_schema_countries.sql) | Страна, валюта, телефонный код | — |
| `cities` | [01_02_schema_cities.sql](../../veze-node-app/init/01_02_schema_cities.sql) | Город, часовой пояс, центр карты, работает ли сервис | → `countries` |
| `street_types` | [01_03_schema_streets.sql](../../veze-node-app/init/01_03_schema_streets.sql) | Справочник типов улиц (вулиця, проспект, площа...) | — |
| `streets` | [01_03_schema_streets.sql](../../veze-node-app/init/01_03_schema_streets.sql) | Улица / проспект / площадь (тип отдельно от названия) | → `cities`, `street_types` |
| `buildings` | [01_04_schema_buildings.sql](../../veze-node-app/init/01_04_schema_buildings.sql) | Дом: номер, название места, координаты | → `streets` |

Справочники (`street_types`, `pickup_point_kinds`) — обычные таблицы с фиксированными строками
(не `ENUM`, см. CLAUDE.md), заполняются `INSERT` прямо в файле схемы, а не в seed — это часть
модели домена, а не тестовые данные.

## Навигация — [02_schema_navigation.sql](../../veze-node-app/init/02_schema_navigation.sql)

| Таблица | Что хранит | Связи |
|---|---|---|
| `road_nodes` | Узлы графа дорог (перекрёстки, повороты) | → `cities` |
| `road_segments` | Направленные участки между узлами (двусторонняя дорога = две строки): скорость, перекрыт | → `road_nodes` ×2, `streets` |
| `bridges` | Мост = улица типа `bridge`; `is_active = FALSE` перекрывает все его участки сразу, не трогая `road_segments.is_active` (ремонты) | → `streets` (1:1) |
| `pickup_point_kinds` | Справочник типов точек посадки (curb, parking, taxi_rank) | — |
| `pickup_points` | Точки посадки/высадки у домов или отдельно (стоянка такси); подсказка об укрытии рядом (`shelter_hint`) | → `buildings` (необязательно), `road_nodes`, `pickup_point_kinds` |
| `depots` | Депо: стоянка и зарядка авто | → `road_nodes` |
| `service_zones` | Полигон, где беспилотнику разрешено работать | → `cities` |

## Авторизация — `init/03_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `auth_providers` | [03_01_schema_users.sql](../../veze-node-app/init/03_01_schema_users.sql) | Справочник способов входа (email/phone/google/apple) | — |
| `users` | [03_01_schema_users.sql](../../veze-node-app/init/03_01_schema_users.sql) | Аккаунт = человек: пароль (один на аккаунт, nullable), блокировка, последний вход, удаление | — |
| `user_identities` | [03_01_schema_users.sql](../../veze-node-app/init/03_01_schema_users.sql) | Способы входа: несколько телефонов, email, `sub` Google/Apple → один `users` | → `users`, `auth_providers` |
| `client_apps` | [03_02_schema_user_sessions.sql](../../veze-node-app/init/03_02_schema_user_sessions.sql) | Справочник приложений (passenger/staff) | — |
| `client_platforms` | [03_02_schema_user_sessions.sql](../../veze-node-app/init/03_02_schema_user_sessions.sql) | Справочник платформ (ios/android/web) | — |
| `user_sessions` | [03_02_schema_user_sessions.sql](../../veze-node-app/init/03_02_schema_user_sessions.sql) | Сессия = вход на устройстве: хэш refresh-токена, push-токен, отзыв | → `users`, `user_identities`, `client_apps`, `client_platforms` |
| `auth_code_purposes` | [03_03_schema_auth_codes.sql](../../veze-node-app/init/03_03_schema_auth_codes.sql) | Справочник назначений кодов (login/verify/password_reset) | — |
| `auth_codes` | [03_03_schema_auth_codes.sql](../../veze-node-app/init/03_03_schema_auth_codes.sql) | Одноразовые коды SMS/email: HMAC кода, попытки, срок | → `auth_providers`, `auth_code_purposes`, `users` (необязательно) |

Авторизация общая для всех ролей. `users` — это человек, а не логин: способов входа у него
сколько угодно (`user_identities`), и все ведут в одни и те же профили. Профили ссылаются на
аккаунт сами (`passengers.user_id`, `employees.user_id`, `UNIQUE`), поэтому один человек может
быть и пассажиром, и сотрудником. Google/Apple опознаются по `sub`, а не по email; склеивать
аккаунты по совпадению email без подтверждения нельзя. Общий профиль на несколько человек
(«семья») пока не закладываем.

## Пассажиры — `init/04_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `passengers` | [04_01_schema_passengers.sql](../../veze-node-app/init/04_01_schema_passengers.sql) | Профиль пассажира: имя, блокировка как пассажира (вход и контакты — в авторизации) | → `users` (1:1) |
| `saved_location_labels` | [04_02_schema_saved_locations.sql](../../veze-node-app/init/04_02_schema_saved_locations.sql) | Справочник меток избранных локаций (home/work/other) | — |
| `saved_locations` | [04_02_schema_saved_locations.sql](../../veze-node-app/init/04_02_schema_saved_locations.sql) | Избранные локации пассажира для быстрого вызова | → `passengers`, `pickup_points`, `saved_location_labels` |
| `card_brands` | [04_03_schema_payment_methods.sql](../../veze-node-app/init/04_03_schema_payment_methods.sql) | Справочник платёжных систем карт (visa/mastercard/prostir) | — |
| `payment_methods` | [04_03_schema_payment_methods.sql](../../veze-node-app/init/04_03_schema_payment_methods.sql) | Привязанные способы оплаты: токен шлюза, last4, бренд — без PAN/CVV | → `passengers`, `card_brands` |

Реквизиты карты (PAN, CVV) в БД не хранятся ни в каком виде — только токен платёжного шлюза
(`provider_token`) и маска для отображения. Привязка идёт по тому же принципу, что и
`VehicleGateway`: сейчас `PaymentGateway` эмулируется, позже — адаптер реального шлюза.
Избранная локация ссылается на существующую `pickup_points`, а не хранит собственные координаты —
адрес остаётся в одном месте.

## Сотрудники — [05_01_schema_employees.sql](../../veze-node-app/init/05_01_schema_employees.sql)

| Таблица | Что хранит | Связи |
|---|---|---|
| `employee_roles` | Справочник ролей (operator/technician/admin) | — |
| `employees` | Оператор, техник или админ: табельный номер, ФИО по документам, депо техника, приём/увольнение | → `users` (1:1), `employee_roles`, `depots` (необязательно) |

Одна таблица на все роли — поля одинаковые. Роль у сотрудника одна. Регистрации нет — заводит
админ. Увольнение (`dismissed_at`) закрывает панель сотрудника и отзывает сессии `staff`,
аккаунт и профиль пассажира остаются. Имя есть и у пассажира, и у сотрудника — это не дубль:
у пассажира «как обращаться в приложении», у сотрудника ФИО из кадров.

## Машины — `init/06_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `vehicle_classes` | [06_01_schema_vehicle_classes.sql](../../veze-node-app/init/06_01_schema_vehicle_classes.sql) | Справочник классов: economy/comfort/business, wagon (до 4), minivan (до 6), delivery (груз до 50 кг, без пассажиров); обещанная вместимость, без цен | — |
| `vehicle_models` | [06_01_schema_vehicle_classes.sql](../../veze-node-app/init/06_01_schema_vehicle_classes.sql) | Модель: места, груз для доставки, ёмкость батареи, запас хода | — |
| `vehicle_sources` | [06_02_schema_vehicles.sql](../../veze-node-app/init/06_02_schema_vehicles.sql) | Справочник источников (simulated/real) — выбор адаптера `VehicleGateway` | — |
| `vehicle_statuses` | [06_02_schema_vehicles.sql](../../veze-node-app/init/06_02_schema_vehicles.sql) | Справочник статусов (idle/busy/to_depot/charging/maintenance/offline) | — |
| `vehicles` | [06_02_schema_vehicles.sql](../../veze-node-app/init/06_02_schema_vehicles.sql) | Машина: номер, цвет, текущие статус, заряд, координаты, пробег | → `vehicle_classes`, `vehicle_models`, `vehicle_sources`, `vehicle_statuses`, `depots` |
| `vehicle_status_log` | [06_02_schema_vehicles.sql](../../veze-node-app/init/06_02_schema_vehicles.sql) | История статусов: загрузка парка, разбор инцидентов | → `vehicles`, `vehicle_statuses`, `employees` (необязательно) |

Класс — обещание клиенту, модель — физическая вместимость: машина подходит классу, если
`seats >= max_passengers` и `cargo_kg >= max_cargo_kg` (проверяет приложение).
Город машины — через домашнее депо (`depots → road_nodes → cities`), отдельно не хранится.
Текущий статус в `vehicles` сознательно дублирует последнюю строку журнала: назначение машины
не может каждый раз искать последнюю запись.

## Тарифы — `init/07_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `tariffs` | [07_01_schema_tariffs.sql](../../veze-node-app/init/07_01_schema_tariffs.sql) | Цены класса в городе; межгород — с `destination_city_id`; версии по `valid_from`; потолок коэффициента | → `cities` ×2, `vehicle_classes`, `employees` |
| `surge_kinds` | [07_02_schema_surge.sql](../../veze-node-app/init/07_02_schema_surge.sql) | Справочник видов коэффициентов (час пик, ночь, спрос, погода, событие, праздник) | — |
| `surge_schedules` | [07_02_schema_surge.sql](../../veze-node-app/init/07_02_schema_surge.sql) | По расписанию: дни недели (битовая маска) + окно местного времени | → `cities`, `surge_kinds`, `employees` |
| `surge_conditions` | [07_02_schema_surge.sql](../../veze-node-app/init/07_02_schema_surge.sql) | Разовые периоды: погода, события; весь город или зона | → `cities`, `service_zones`, `surge_kinds`, `employees` |
| `surge_demand_levels` | [07_02_schema_surge.sql](../../veze-node-app/init/07_02_schema_surge.sql) | Пороги «заявки ÷ свободные машины» → коэффициент | → `cities` |
| `location_fees` | [07_03_schema_location_fees.sql](../../veze-node-app/init/07_03_schema_location_fees.sql) | Фиксированный сбор за место (платный въезд в аэропорт, парковка): при посадке и/или высадке | → `pickup_points` или `service_zones` (ровно одно), `employees` |

Тариф не редактируется — добавляется новая версия, действует последняя с `valid_from <= сейчас`;
поездка будет ссылаться на версию, по которой посчитана. Валюта — из страны города.
Итоговый коэффициент = произведение действующих (по каждому виду — наибольший), не выше
`tariffs.max_surge`. Окна расписания — в местном времени города (`cities.timezone`).
Сбор за место — не коэффициент: прибавляется суммой после surge, промокод на него не действует,
с поездки берётся не больше одного раза.

## Ограничения сервиса — [08_01_schema_service_restrictions.sql](../../veze-node-app/init/08_01_schema_service_restrictions.sql)

| Таблица | Что хранит | Связи |
|---|---|---|
| `restriction_kinds` | Справочник видов (air_alert/curfew/emergency) и их правил: блокирует ли заказы, отключает ли surge, бесплатна ли отмена, текст предупреждения; что делают свободные машины (в депо / стоять на месте, запас времени до начала) | — |
| `service_restrictions` | Разовые: тревога, ЧС; весь город или зона; `external_id` из API тревог | → `cities`, `service_zones`, `restriction_kinds`, `employees` |
| `service_restriction_schedules` | По расписанию: комендантский час (окно местного времени, `valid_from`/`valid_to`) | → `cities`, `restriction_kinds`, `employees` |

Это не цена, а правила работы сервиса. Тревога: заказы принимаются с предупреждением, surge
выключен, отмена бесплатна, пассажиру в пути предлагается высадка у точки с укрытием
(`pickup_points.shelter_hint`); свободные машины в депо не едут (город без такси, скопление парка
в одном месте — уязвимость), стоят на месте. Комендантский час: новые поездки не принимаются,
свободные машины заранее уходят в депо (время пути + `depot_lead_min`), занятые — после высадки;
ночь в депо — зарядка и обслуживание. Ночь без комендантского часа — часть машин уходит на
зарядку по прогнозу спроса, это логика приложения. Потеря GPS или
связи — событие машины через `VehicleGateway` (будущие `incidents`), не здесь.

## Поездки — `init/09_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `promo_codes` | [09_01_schema_promo_codes.sql](../../veze-node-app/init/09_01_schema_promo_codes.sql) | Промокод: % скидки, потолок, город/класс, срок, лимиты использований | → `cities`, `vehicle_classes`, `employees` |
| `ride_statuses` | [09_02_schema_rides.sql](../../veze-node-app/init/09_02_schema_rides.sql) | Справочник статусов (PRD, раздел 4) | — |
| `ride_cancel_reasons` | [09_02_schema_rides.sql](../../veze-node-app/init/09_02_schema_rides.sql) | Справочник причин отмены | — |
| `rides` | [09_02_schema_rides.sql](../../veze-node-app/init/09_02_schema_rides.sql) | Поездка: пассажир, версия тарифа, машина, точки, число пассажиров, карта, промокод, ограничение при заказе, PIN, расчётные и фактические км/время, `quoted_price` / `final_price` | → `passengers`, `tariffs`, `vehicles`, `pickup_points` ×2, `payment_methods`, `promo_codes`, `service_restrictions`, `ride_statuses`, `ride_cancel_reasons` |
| `ride_deliveries` | [09_02_schema_rides.sql](../../veze-node-app/init/09_02_schema_rides.sql) | Доставка (1:1 с поездкой): получатель, телефон, PIN получателя, посылка, вес | → `rides` |
| `ride_event_types` | [09_03_schema_ride_events.sql](../../veze-node-app/init/09_03_schema_ride_events.sql) | Справочник событий (смена статуса, смена высадки, двери, PIN, помощь, укрытие, аварийная остановка) | — |
| `ride_actor_kinds` | [09_03_schema_ride_events.sql](../../veze-node-app/init/09_03_schema_ride_events.sql) | Кто инициировал: пассажир, машина, система, сотрудник | — |
| `ride_events` | [09_03_schema_ride_events.sql](../../veze-node-app/init/09_03_schema_ride_events.sql) | История поездки: статусы (отсюда время каждого этапа), смена высадки, действия оператора | → `rides`, `ride_event_types`, `ride_statuses`, `pickup_points`, `ride_actor_kinds`, `employees` |
| `ride_track_points` | [09_03_schema_ride_events.sql](../../veze-node-app/init/09_03_schema_ride_events.sql) | Трек: координаты машины раз в ~2 с | → `rides` |
| `price_item_types` | [09_04_schema_ride_prices.sql](../../veze-node-app/init/09_04_schema_ride_prices.sql) | Справочник строк чека (тариф, надбавка, сбор, скидка, ожидание, отмена) | — |
| `ride_price_items` | [09_04_schema_ride_prices.sql](../../veze-node-app/init/09_04_schema_ride_prices.sql) | Расшифровка цены; сумма строк = `final_price` | → `rides`, `price_item_types`, `location_fees` |
| `ride_surge_factors` | [09_04_schema_ride_prices.sql](../../veze-node-app/init/09_04_schema_ride_prices.sql) | Какие коэффициенты действовали при заказе и с каким множителем | → `rides`, `surge_kinds` |
| `payment_operations` | [09_05_schema_payments.sql](../../veze-node-app/init/09_05_schema_payments.sql) | Справочник операций (hold/capture/void/refund) | — |
| `payment_statuses` | [09_05_schema_payments.sql](../../veze-node-app/init/09_05_schema_payments.sql) | Справочник статусов (pending/succeeded/failed) | — |
| `payments` | [09_05_schema_payments.sql](../../veze-node-app/init/09_05_schema_payments.sql) | Журнал операций со шлюзом: сумма, карта, ссылка на родительскую операцию, ключ идемпотентности, ошибка | → `rides`, `payment_methods`, `payments` (родитель) |
| `rating_tags` | [09_06_schema_ratings.sql](../../veze-node-app/init/09_06_schema_ratings.sql) | Справочник тегов оценки (похвала / жалоба) | — |
| `ratings` | [09_06_schema_ratings.sql](../../veze-node-app/init/09_06_schema_ratings.sql) | Оценка поездки 1–5 + комментарий, одна на поездку | → `rides` |
| `rating_tag_links` | [09_06_schema_ratings.sql](../../veze-node-app/init/09_06_schema_ratings.sql) | Теги, выбранные к оценке | → `ratings`, `rating_tags` |
| `incident_types`, `incident_severities`, `incident_statuses`, `incident_culprits` | [09_07_schema_incidents.sql](../../veze-node-app/init/09_07_schema_incidents.sql) | Справочники инцидентов | — |
| `incidents` | [09_07_schema_incidents.sql](../../veze-node-app/init/09_07_schema_incidents.sql) | Инцидент поездки или машины без поездки: кто сообщил, кто ведёт, время реакции, виновник, решение, оценка помощи | → `rides` или `vehicles` (ровно одно), справочники, `ride_actor_kinds`, `employees` ×2 |

В `rides` нет дублей: город, город назначения и класс — через `tariff_id` (версия тарифа
неизменна), время этапов — из `ride_events`, состав цены — из `ride_price_items`.
`status_id` — кэш последней смены статуса. Правила PRD держит сама БД: одна активная поездка
у пассажира и одна у машины — `UNIQUE` на вычисляемых колонках (`NULL` для завершённых и
отменённых); машина обязательна начиная с `assigned`; итог есть ровно у завершённых и
отменённых; причина — ровно у отменённых. При отмене строки заказа в чеке удаляются, остаётся
только плата за отмену. PIN хранится открыто: его показывают пассажиру, а хэш 4 цифр ничего
не защищает.

Оплата: при заказе блокируется `quoted_price` с запасом на ожидание, после поездки списывается
`final_price`, при бесплатной отмене блокировка снимается. Успешное списание у поездки одно —
`UNIQUE` на вычисляемой колонке; неудачные попытки остаются в журнале. Долг — завершённая
поездка с суммой без успешного списания. Рейтингов пассажира и оператора нет: поведение
пассажира — инциденты с `culprit = passenger`, работа оператора — время реакции и `help_score`.

## Тестовые данные

- [10_seed_geo.sql](../../veze-node-app/init/10_seed_geo.sql),
  [11_seed_navigation.sql](../../veze-node-app/init/11_seed_navigation.sql) — фрагмент центра Киева,
  координаты приблизительные.
- [12_seed_users.sql](../../veze-node-app/init/12_seed_users.sql) — аккаунты: пассажир с двумя
  телефонами, пассажир через Google, оператор-пассажир, админ, техник. Пароль `veze-test-1`.
- [13_seed_vehicles.sql](../../veze-node-app/init/13_seed_vehicles.sql) — 6 моделей, 9 эмулированных
  машин всех классов в депо «Центр» в разных статусах, журнал статусов.
- [14_seed_tariffs.sql](../../veze-node-app/init/14_seed_tariffs.sql) — тарифы Киева (две версии
  эконома) и Львова, межгород Киев ↔ Львов, час пик, ночь, снегопад, концерт, уровни спроса,
  сбор за платную парковку.
- [15_seed_service_restrictions.sql](../../veze-node-app/init/15_seed_service_restrictions.sql) —
  комендантский час Киева (старый и текущий режим) и Львова, три тревоги (одна ещё идёт).
- [16_seed_rides.sql](../../veze-node-app/init/16_seed_rides.sql) — карты пассажиров, промокоды,
  4 поездки: завершённая с часом пик, промокодом и сбором; отменённая; идущая сейчас; доставка.
- [17_seed_payments.sql](../../veze-node-app/init/17_seed_payments.sql) — операции оплаты этих
  поездок, включая отклонённую блокировку.
- [18_seed_feedback.sql](../../veze-node-app/init/18_seed_feedback.sql) — оценки с тегами и
  4 инцидента (забытая вещь, грязь по вине пассажира, лидар в депо, потеря связи).
- Примеры запросов — [queries/navigation-examples.sql](../../veze-node-app/queries/navigation-examples.sql),
  [queries/auth-examples.sql](../../veze-node-app/queries/auth-examples.sql),
  [queries/vehicles-examples.sql](../../veze-node-app/queries/vehicles-examples.sql),
  [queries/restrictions-examples.sql](../../veze-node-app/queries/restrictions-examples.sql),
  [queries/rides-examples.sql](../../veze-node-app/queries/rides-examples.sql),
  [queries/payments-feedback-examples.sql](../../veze-node-app/queries/payments-feedback-examples.sql).
