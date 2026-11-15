# Открыть и восстановить проект

## Уже работающая Studio пользователя

Не нужно пересоздавать игру. Она сохранена локально как NUMBER_RUSH.rbxl и опубликована приватно как NUMBER RUSH [TEST]; Studio Access to API Services включён. Оригинальный файл ещё не передан помощнику.

Чтобы добавить точную сцену в GitHub: остановить Play, сохранить локальную копию через File → Save to File As, прислать `.rbxl` или `.rbxlx` в диалог. После этого сохранить оригинал в `places/original/` и сравнить Source с `src`. Не считать реконструкцию заменой оригинала без сверки.

## Открыть восстановленную сцену

1. Скачать репозиторий или файл `places/NUMBER_RUSH_reconstructed.rbxlx`.
2. В Studio: File → Open from File, выбрать `.rbxlx`.
3. Проверить Explorer по таблице ниже. Сцена построена из источников и простой площадки, её импорт нужно подтвердить в Studio.
4. Для DataStore связать её с нужной **тестовой** игрой Roblox через сохранение/публикацию. Не публиковать поверх единственного оригинала до локальной резервной копии.
5. File → Experience Settings / Game Settings → Security → Enable Studio Access to API Services → Save.
6. F5, дождаться загрузки, проверить Output. Новое experience получает отдельные данные; старое — использует уже сохранённый профиль.

## Вручную перенести источники

| Путь Studio | Тип | Файл |
|---|---|---|
| ReplicatedStorage/GameConfig | ModuleScript | src/ReplicatedStorage/GameConfig.lua |
| ReplicatedStorage/NumberRushRemotes | Folder | создать |
| …/SpinRequest | RemoteEvent | создать |
| …/SpinResult | RemoteEvent | создать |
| ServerScriptService/GameServer | Script | src/ServerScriptService/GameServer.server.lua |
| ServerScriptService/NumberRules | ModuleScript | src/ServerScriptService/NumberRules.lua |
| ServerScriptService/NumberGenerator | ModuleScript | src/ServerScriptService/NumberGenerator.lua |
| ServerScriptService/NumberEconomy | ModuleScript | src/ServerScriptService/NumberEconomy.lua |
| ServerScriptService/PlayerDataStore | ModuleScript | src/ServerScriptService/PlayerDataStore.lua |
| ServerScriptService/NumberRegistry | ModuleScript | src/ServerScriptService/NumberRegistry.lua |
| ServerScriptService/SpinService | ModuleScript | src/ServerScriptService/SpinService.lua |
| StarterPlayer/StarterPlayerScripts/NumberRushUI | LocalScript | src/StarterPlayer/StarterPlayerScripts/NumberRushUI.client.lua |
| StarterPlayer/StarterPlayerScripts/CollectionUI | LocalScript | src/StarterPlayer/StarterPlayerScripts/CollectionUI.client.lua |

В Studio имена **без расширений**. Вставлять Source целиком, сохраняя тип и регистр. При правках остановить Play, Ctrl+S; изменение тестовой копии во время Play не является сохранением редакторского исходника.

`devtools` не переносить в рабочую сцену автоматически. Три исторических диагностических Script должны быть выключены (`Enabled = false`). BalanceSaveTest выставляет 90000 и при повторном включении меняет баланс снова.

## Rojo, необязательно

`default.project.json` описывает то же рабочее дерево. Это возможность для будущей синхронизации, пользователь пока Rojo не устанавливал и с ним не работал. Не заставлять новичка менять процесс ради чтения резервной копии. Обмен файлами Git сам по себе не синхронизирует открытую Studio.

## Что ещё настроить позднее

Максимум 6 игроков, production experience, права тестировщиков, устройства, Game Pass/Developer Product IDs. Эти настройки не считаются автоматически применёнными данным репозиторием.
