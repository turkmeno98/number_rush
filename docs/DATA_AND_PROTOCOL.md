# Сохранения и сетевой протокол

## Дополнение шага 34 — выдача по региону

SpinRequest = operatorId:string, regionId:string, sequence:integer. Старый пакет code/sequence отклоняется без оплаты. Started содержит OperatorId/RegionId/Duration; код определяется только сервером. Предмет v3 хранит EconomyVersion=3, RegionId и OfferPrice; для оценки применяется Regional с престижем 1. Цена и регион фиксируются в PendingSpin. Повтор кандидата использует сохранённый контекст, возврат — PendingSpin.Price. Legacy PendingSpin без EconomyVersion продолжает восстанавливаться через прежний CodeOffers; старые предметы не переписываются. SchemaVersion и имена/ключи DataStore прежние. Ниже старые описания выбора кода относятся к исторической версии.

## Дополнение шага 33 — свободная замена и EquipBest

SlotRequest допускает действие EquipBest: клиент отправляет action, nil, nil, expectedRevision. Сервер сам выбирает предметы по IncomePerHour, SalePrice и стабильному IssuanceId; клиент не передаёт лучший набор. В одном снимке сохраняются все назначения, ревизия, баланс и остаток дохода. Повтор оптимального набора возвращает Unchanged. Неизвестный результат записи переводит сессию в NeedsRecovery без слепого отката. ChangedAt остаётся исторической меткой для совместимости; NextChangeAt и CooldownRemaining всегда нули. Формат/имена DataStore и SchemaVersion не менялись. Старые описания часового ограничения ниже отменены.

## Окружения

| Данные | Studio | Запуск опубликованной игры |
|---|---|---|
| Профили | NR_Profiles_DEV_v1 | NR_Profiles_LIVE_v1 |
| Реестр номеров | NR_Numbers_DEV_v1 | NR_Numbers_LIVE_v1 |
| Диагностический счётчик | NR_ConnectionCheck_v1 / CheckCounter | Не используется |

Хранилища дополнительно изолированы Roblox experience. Новый проект/другое experience не увидит старые данные, даже при одинаковых именах. Не менять имена для обычного обновления скриптов. Git не содержит сами значения DataStore.

## Профиль

Ключ `Player_<UserId>`. Верхний уровень: `SchemaVersion = 1`, `Data`, `Session = {Id, ExpiresAt}`, `UpdatedAt`.

Постоянные Data:

- Balance, Inventory (словарь IssuanceId → предмет), IncomeSlots (книга назначений).
- InventoryCapacity = 25, IncomeSlotCount = 3 по умолчанию.
- NextSpinSequence: появляется при инициализации сервера, начинается с 1.
- PendingSpin: журнал одной незавершённой платной выдачи.
- LastSpin: последняя квитанция Success/Cancelled для повторного ответа без новой оплаты.
- IncomeRemainder: целый остаток 0..3599999; доля рубля с делителем 3600000. Отсутствующее поле старого профиля инициализируется нулём без сброса других данных. Повреждённое поле отклоняется.

Онлайн-доход: сессионные IncomeClock/IncomeRate/IncomeStoppedAt и функции BeforeSave/UpdateIncomeRate не сохраняются. Время берётся из os.clock в миллисекундах; на новом сервере начинается заново, офлайн не оплачивается. Сохраняются одновременно Balance и IncomeRemainder. BeforeSave начисляет до снимка, UpdateIncomeRate рассчитывает старый период по старой ставке перед фиксацией новой. При выходе IncomeStoppedAt фиксирует конец оплачиваемого времени. Автоматические тики пропускают занятые операции и затем учитывают прошедшее время; NeedsRecovery и истекающая аренда блокируют выплаты. Авария может потерять доход после последнего успешного снимка; абсолютная сохранность не обещается.

Session.Token/LeaseUntil/Busy/Closing/SpinBusy/RequestBusy/NeedsRecovery/BalanceValue — поля серверной сессии в памяти, не часть Data. Аренда 120 секунд, автосохранение раз в 30 секунд, контроль срока каждые 5 секунд. Ошибка чтения не создаёт новый профиль поверх существующего.

## Реестр

Ключ — **11 цифр полного номера**, например `79035831946`, без плюса и пробелов. Регион/бренд не создают дополнительный экземпляр.

Запись: SchemaVersion, State (`Reserved`, `Owned`, `Free`), OwnerId, OperationId, IssuanceId, Generation, UpdatedAt; после отмены резерва LastOwnerId. Новый выпуск свободной комбинации увеличивает Generation и получает новый IssuanceId.

- Reserve(fullNumber, userId, operationId): резерв или возврат результата той же операции; занятый чужой номер → Occupied.
- Confirm(...): Reserved → Owned; повтор подтверждения идемпотентен.
- Cancel(...): освобождает только Reserved; Owned → AlreadyOwned. **Это не готовый метод продажи номера.**

Все три метода возвращают `record` либо `nil, errorCode, details`. UpdateAsync решает гонку на одном ключе; профиль и реестр не являются одной атомарной записью.

## Выдача

1. Проверить запрос, последовательность, деньги, место.
2. Выбрать категорию, подготовить семизначную часть и оценку из серверной конфигурации.
3. Одним сохранением профиля записать PendingSpin, удержать цену и увеличить NextSpinSequence.
4. Дождаться минимальных 6 секунд от старта.
5. Reserve и Confirm в реестре для того же OperationId.
6. Добавить Inventory[IssuanceId], записать LastSpin, удалить PendingSpin и сохранить профиль.
7. Только после подтверждения сохранения отправить Success.

При Occupied сохраняется категория, меняется только кандидат. До 8 попыток. После 8 подтверждённых Occupied — сохранённая отмена и возврат. При неизвестном результате записи нельзя генерировать новый кандидат: операция остаётся для Recover. При следующей загрузке Recover запускается до DataReady.

Старый Sequence не становится новым платежом. Повтор последней квитанции возвращает результат, ещё более старый запрос отклоняется. После переподключения клиент берёт актуальную последовательность сервера.

## RemoteEvent

Путь: `ReplicatedStorage/NumberRushRemotes`.

| Событие | Направление | Параметры |
|---|---|---|
| SpinRequest | Клиент → сервер | operatorId: string, regionId: string, sequence: integer |
| SpinResult Started | Сервер → клиент | Status, Sequence, Code, Duration |
| SpinResult Success | Сервер → клиент | Status, Sequence, Balance, Item, NextSequence, InventoryCount |
| SpinResult Cancelled | Сервер → клиент | Status, Sequence, Balance, Reason, NextSequence, InventoryCount |
| SpinResult Error | Сервер → клиент | Status, ErrorCode, Sequence?, Message, NextSequence?, Ready |
| SlotRequest | Клиент → сервер | action: GetState/Install/Remove, slotIndex?, issuanceId?, expectedRevision? |
| SlotResult | Сервер → клиент | Status: Ready/Success/Unchanged/Error, State?, ErrorCode?, Message?, Ready? |

Предварительные ошибки могут не иметь Sequence. Клиент игнорирует Busy во время ожидания текущей операции. Таймаут UI 60 секунд показывает задержку, но не отправляет новый платёж и не включает кнопку для повторного списания.

## Отображение

- `leaderstats/Рубли`: IntValue, отражает серверный Balance.
- `NumberInventory/<IssuanceId>`: Folder с примитивными свойствами предмета в Attributes.
- Player Attributes: DataReady, InventoryCapacity, IncomeSlotCount, InventoryCount, NextSpinSequence.
- Предмет: FullNumber, DisplayNumber, Digits, Code, ProfileId, OperatorId, OperatorName, Region, RarityIndex/Name, BasePrice, SalePrice, IncomePerHour, DigitMultiplier, PrestigeMultiplier, CodeMatchMultiplier, HasCodeMatch, IssuanceId, Generation, OperationId, OriginalOwnerId, CanBoostSale, Location, AcquiredAt.

Папки/атрибуты клиента не являются источником прав владения. Следующие операции должны читать профиль и реестр, не доверять изменениям GUI.

## Назначение доходных слотов — сервер подготовлен, UI и начисление впереди

IncomeSlotService поддерживает Initialize/GetState, Install и Remove. GameServer обрабатывает SlotRequest, но текущая CollectionUI пока не отправляет такие запросы.

Data.IncomeSlots хранит строковые ключи "1"…"5": {IssuanceId?, ChangedAt?}. После снятия ChangedAt сохраняется. Data.SlotRevision добавляется как 0 только если отсутствует; после успешного изменения увеличивается. Item.Location = "IncomeSlot" и Item.IncomeSlotIndex согласуются с книгой в одном сохранении профиля. Серверный профиль — источник принадлежности; эта операция владельца глобального реестра не меняет.

Install требует unlocked slotIndex, IssuanceId из своего Inventory, Location Inventory и актуальную revision. Один выпуск не может стоять в двух слотах. Повтор уже установленного назначения с текущей revision — Unchanged без записи и сброса таймера; старый revision — StaleSlots, не новая операция. Замена разрешена через 3600 секунд от установки. Remove бесплатен, не сбрасывает таймер, но последний занятый слот снять нельзя.

GetState без дополнительных аргументов; Install(slotIndex, issuanceId, expectedRevision); Remove(slotIndex, nil, expectedRevision) на RemoteEvent. Ответ State содержит Revision, SlotCount, ActiveCount, TotalBaseIncomePerHour, IncomeEnabled=false, ServerTime и массив Slots. Ряды: SlotIndex, IssuanceId?, DisplayNumber?, RarityName?, IncomePerHour?, LastChangedAt, NextChangeAt, CooldownRemaining.

В Players/<игрок>/IncomeSlots публикуются три Folder по номерам слотов с атрибутами ряда. У Player есть SlotRevision, ActiveIncomeSlotCount, TotalBaseIncomePerHour, IncomeEnabled=false. Это отображение, не доверенный ввод и не реальное начисление.

SlotBusy защищает назначение от спина и автосохранения. Сервис отклоняет работу при SpinBusy/RequestBusy/Busy/PendingSpin; GameServer не запускает новый спин/автосохранение при SlotBusy. Ошибка записи блокирует сессию до переподключения, слепого отката после неизвестного результата нет. Старые данные не сбрасываются при нарушении связей книги и Inventory.

При последующем добавлении дохода учитывать те же блокировки и сначала рассчитывать заработанное старым назначением, затем менять слот. Пока сервис вообще не меняет Balance и не создаёт часы начисления.
