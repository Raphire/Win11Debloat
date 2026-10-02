# Win11Debloat — Windows 11 po polsku

Polski interfejs, trzy presety i wybór tapety działają wewnątrz Win11Debloat. `Run.bat` uruchamia lokalną kopię programu przez Windows PowerShell 5.1. Nie trzeba znać poleceń PowerShell ani używać instalatora `Get.ps1`.

## Przygotowanie wielu laptopów

1. Pobierz pełne repozytorium i rozpakuj je. Nie wystarczy sam `Run.bat`.
2. Jeśli chcesz korzystać z pendrive’a, samodzielnie skopiuj na niego cały katalog. Nie trzeba nazywać nośnika „Nowy” ani ustawiać konkretnej litery dysku.
3. Opcjonalnie dodaj obrazy JPG, JPEG, PNG lub BMP do `Assets\Wallpapers`. Bez plików program oferuje wbudowaną czarną tapetę.
4. Na laptopie z Windows 11 zaloguj się na konto administratora, którego profil przygotowujesz, i kliknij `Run.bat`.
5. Wybierz preset, potem tapetę. Enter wybiera **Normalny**, a w wyborze tapety — `default.jpg`, jeśli istnieje, w przeciwnym razie czarną. Opcja **0** pozostawia tapetę bez zmian.
6. Zaakceptuj UAC i sprawdź listę zmian. Enter uruchamia przygotowanie.
7. Sprawdź końcowe podsumowanie i dziennik, uruchom laptop ponownie i sprawdź jego działanie. Dopiero potem przygotuj kolejny.

Nie ma dopasowywania tapet do producenta lub modelu. Ta sama lista jest dostępna dla wszystkich laptopów.

### Presety

| Preset | Zakres |
| --- | --- |
| **Normalny** | Zalecane ustawienia z bieżącego `DefaultSettings.json` i domyślna lista aplikacji. |
| **Agresywny** | Normalny oraz dodatkowe wyłączenia powiadomień, lokalizacji, części AI i efektów interfejsu; ukrywanie wybranych elementów Eksploratora i usuwanie aplikacji OEM. Wymaga wpisania **TAK**. |
| **Gaming** | Normalny oraz wyłączenie nagrywania Xbox, integracji Game Bar, powiadomień i efektów interfejsu. Zachowuje pakiety Xbox/Gaming. Nie gwarantuje większej liczby FPS; nagrywanie przez Game Bar zostaje wyłączone. |

Presety nie wybierają wymuszonego usuwania Edge, wyłączenia automatycznego szyfrowania BitLocker ani usuwania Store, Terminala, Kalkulatora czy Zdjęć. Nie wyłączają Defendera ani Windows Update i nie usuwają sterowników. Agresywny zachowuje HP Sure Shield AI, ale usuwa inne narzędzia OEM, w tym narzędzia zasilania, diagnostyki i wsparcia. Sprawdź, czy są potrzebne na danym sprzęcie. Ustawienia nieobsługiwane przez daną wersję Windows lub sprzęt są pomijane.

**Tryb własny** otwiera dotychczasowy interfejs. Korzysta z tłumaczenia `pl-PL`, jeśli jego pliki znajdują się w `Config\Languages`; bez nich używa angielskiego. Nadal umożliwia ręczny wybór funkcji spoza presetów. Część istniejących komunikatów konsoli pozostaje po angielsku.

## Tapeta i kopie zapasowe

- **Tylko tapeta** zmienia tło bez debloatu. Wybrany obraz jest konwertowany do BMP i zapisywany lokalnie; tapeta nie zależy później od podłączonego pendrive’a.
- Przed zmianą tapety zapisywana jest kopia poprzedniego obrazu i jego ustawień. **Przywróć ostatnią kopię tapety** używa najnowszej kopii dla bieżącego konta i komputera.
- Brak lub uszkodzenie wybranego obrazu nie zatrzymuje pozostałych zmian, ale końcowy status zgłasza błąd. Nie traktuj takiego uruchomienia jako w pełni udanego.
- Tapeta dotyczy bieżącego użytkownika, nie innych kont ani profilu Sysprep. Podanie innych poświadczeń w UAC jest odrzucane.
- **Przywróć kopię rejestru lub menu Start** otwiera dotychczasowe okno przywracania. Kopia rejestru nie przywraca usuniętych aplikacji — trzeba zainstalować je osobno.
- Presety wymagają kopii rejestru dla zmian rejestrowych i proszą istniejący mechanizm o punkt przywracania. Może on użyć punktu z ostatnich 24 godzin. Błąd tworzenia punktu jest zgłaszany; nie jest obietnicą pełnego cofnięcia wszystkich zmian.

W trybie uruchamianym przez `Run.bat`:

| Dane | Lokalizacja |
| --- | --- |
| Kopie rejestru | `%ProgramData%\Win11Debloat\Backups` |
| Ostatnie ustawienia | `%ProgramData%\Win11Debloat\LastUsedSettings.json` |
| Lokalne obrazy tapet | `%LOCALAPPDATA%\Win11Debloat\Wallpapers` |
| Kopie tapet | `%LOCALAPPDATA%\Win11Debloat\Backups\Wallpaper` |
| Dziennik uruchomienia | `Logs\<NAZWA_KOMPUTERA>\<DATA_ID>` w kopii repozytorium |

Dzienniki mogą zawierać nazwy komputera, użytkownika i aplikacji. Nie publikuj ich bez sprawdzenia. Katalog repozytorium musi umożliwiać zapis dzienników. Internet przydaje się do obsługi WinGet i usług systemowych; nie gwarantujemy pracy całkowicie offline.

Kody zakończenia: **0** — bez zgłoszonych błędów, **1** — błąd, **2** — nie można potwierdzić usunięcia aplikacji, **3** — anulowanie lub zamknięcie interfejsu bez zastosowania zmian. Wyjście z menu bez rozpoczynania zadania zwraca 0.

## Weryfikacja przed użyciem na 26 laptopach

Na macOS można przygotować kod i uruchomić testy logiki z atrapami. Nie da się w ten sposób potwierdzić działania UAC, rejestru, WPF, Appx ani tapet w Windows. Te zmiany wymagają odbioru w Windows 11, najlepiej w maszynie wirtualnej z migawką, a następnie na jednym laptopie pilotażowym.

W Windows PowerShell 5.1 uruchom:

```powershell
.\Scripts\Run-Tests.ps1 -Bootstrap
```

Przed wdrożeniem sprawdź na używanych wydaniach Windows 11 Home/Pro:

- każdy preset; Agresywny również z odmową potwierdzenia;
- pełny polski interfejs, import, eksport i okno przywracania;
- uruchamianie z różnych liter dysku i folderu ze spacjami, apostrofem, `&` i `!`;
- UAC z tym samym kontem, anulowanie UAC i odrzucenie innego konta;
- czarną tapetę, każdy format obrazu, brak pliku i uszkodzony obraz;
- tapetę po odłączeniu nośnika, ponownym logowaniu i restarcie;
- ponowne przygotowanie oraz przywrócenie kopii rejestru, menu Start i tapety;
- pliki kopii i dzienniki oraz kody zakończenia przy błędzie i anulowaniu;
- sieć, dźwięk, kamerę, klawisze funkcyjne, zarządzanie baterią, Store i wymagane gry.

Nie wykonuj debloatu podczas testów na komputerze roboczym. Dla bezpiecznej symulacji uruchom `.\Win11Debloat.ps1 -Preset Normal -Language pl-PL -WhatIf -Silent` w Windows PowerShell 5.1. Symulacja nie potwierdza poprawności rzeczywistych zmian.
