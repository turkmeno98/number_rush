# Сохранения и сетевой протокол

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

- Balance, Inventory (словарь IssuanceId → предмет), IncomeSlots (пока пустая таблица).
- InventoryCapacity = 25, IncomeSlotCount = 3 по умолчанию.
- NextSpinSequence: появляется при инициализации сервера, начинается с 1.
- PendingSpin: журнал одной незавершённой платной выдачи.
- LastSpin: последняя квитанция Success/Cancelled для повторного ответа без новой оплаты.

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
| SpinRequest | Клиент → сервер | code: string, sequence: integer |
| SpinResult Started | Сервер → клиент | Status, Sequence, Code, Duration |
| SpinResult Success | Сервер → клиент | Status, Sequence, Balance, Item, NextSequence, InventoryCount |
| SpinResult Cancelled | Сервер → клиент | Status, Sequence, Balance, Reason, NextSequence, InventoryCount |
| SpinResult Error | Сервер → клиент | Status, ErrorCode, Sequence?, Message, NextSequence?, Ready |
| SlotRequest | Клиент → сервер | Подготовлен для шага 28, обработчик и контракт ещё не реализованы |
| SlotResult | Сервер → клиент | Подготовлен для шага 28, обработчик и контракт ещё не реализованы |

Предварительные ошибки могут не иметь Sequence. Клиент игнорирует Busy во время ожидания текущей операции. Таймаут UI 60 секунд показывает задержку, но не отправляет новый платёж и не включает кнопку для повторного списания.

## Отображение

- `leaderstats/Рубли`: IntValue, отражает серверный Balance.
- `NumberInventory/<IssuanceId>`: Folder с примитивными свойствами предмета в Attributes.
- Player Attributes: DataReady, InventoryCapacity, IncomeSlotCount, InventoryCount, NextSpinSequence.
- Предмет: FullNumber, DisplayNumber, Digits, Code, ProfileId, OperatorId, OperatorName, Region, RarityIndex/Name, BasePrice, SalePrice, IncomePerHour, DigitMultiplier, PrestigeMultiplier, CodeMatchMultiplier, HasCodeMatch, IssuanceId, Generation, OperationId, OriginalOwnerId, CanBoostSale, Location, AcquiredAt.

Папки/атрибуты клиента не являются источником прав владения. Следующие операции должны читать профиль и реестр, не доверять изменениям GUI.
