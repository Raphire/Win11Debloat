# Win11Debloat

Win11Debloat è uno script PowerShell, facile da usare e leggero, in grado di rimuovere le applicazioni bloatware preinstallate in Windows, di disabilitare la telemetria e di riordinare l'esperienza disabilitando o rimuovendo gli elementi intrusivi dell'interfaccia, gli annunci pubblicitari e altro ancora. Non c'è bisogno di esaminare faticosamente tutte le impostazioni o di rimuovere le app una per una. Win11Debloat rende il processo facile e veloce!

È possibile scegliere esattamente le modifiche da apportare allo script o utilizzare le impostazioni predefinite. Se non si è soddisfatti delle modifiche, è possibile ripristinarle facilmente utilizzando i file di registro inclusi nella cartella “Regfiles”. Tutte le applicazioni rimosse possono essere reinstallate dal Microsoft store.

![Win11Debloat Menu](/Assets/menu.png)

#### Lo script vi ha aiutato? Potete offrire un caffè per sostenere il lavoro

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Features

> [!Tip]
> Selezionare Custom Mode per personalizzare lo script in base alle proprie esigenze o selezionare [default mode](#default-mode)  per applicare le modifiche consigliate

#### App Removal

- Rimuove un'ampia gamma di applicazioni bloatware
- Rimuove tutte le app pinnate nel menu start per l'utente corrente o per tutti gli utenti esistenti e nuovi (solo Windows11)

#### Telemetry, Tracking & Suggested Content

- Disabilita la telemetria, i dati diagnostici, la cronologia delle attività, il tracciamento dell'avvio delle app e gli annunci mirati. 
- Disabilita i suggerimenti, i trucchi, i consigli e gli annunci in start, Impostazioni, Notifiche, Esplora file e sulla schermata di blocco.

#### Bing Web Search, Copilot & More

- Disabilita e rimuove la ricerca web di Bing e Cortana dalla barra di ricerca (start) di Windows
- Disabilita Copilot di Windows. (Windows 11 only)
- Disabilita gli snapshot di Windows Recall. (Windows 11 only)

#### File Explorer

- Mostra file, cartelle e unità nascoste. 
- Mostra le estensioni dei tipi di file conosciuti. 
- Nasconde la sezione `galleria` dal pannello laterale di Esplora file. (solo Windows 11) 
- Nasconde la cartella oggetti 3D, musica o onedrive dal pannello laterale di Esplora file. (solo Windows 10) 
- Nasconde le voci duplicate delle unità rimovibili dal pannello laterale di Esplora file, in modo che rimanga solo la voce sotto "Questo PC".

#### Taskbar

- Allinea le icone della barra delle applicazioni a sinistra. (solo Windows 11) 
- Nasconde o modifica l'icona di ricerca/la casella di ricerca sulla barra delle applicazioni. (solo Windows 11) 
- Nasconde il pulsante `Visualizzazione attività` dalla barra delle applicazioni. (Solo Windows 11) 
- Disattiva il servizio widget e nasconde l'icona dalla barra delle applicazioni. 
- Nasconde l'icona della chat (meet now) dalla barra delle applicazioni.

#### Context Menu

- Ripristinare il vecchio menu contestuale in stile Windows 10. (solo Windows 11) 
- Nasconde le opzioni "Includi nella libreria", "Dai accesso a" e "Condividi" dal menu contestuale. (Solo Windows 10)

#### Other

- Disabilita la registrazione del gioco/schermo di Xbox (blocca anche i popup di sovrapposizione del gioco). 

#### Advanced Features

- Modalità Sysprep per applicare le modifiche al profilo utente predefinito di Windows.

## Default Mode

La modalità predefinita applica le modifiche consigliate per la maggior parte degli utenti; per ulteriori informazioni, espandere la sezione sottostante.

<details>
  <summary>Click to expand</summary>
  <blockquote>
    
    La Default mode applica le seguenti modifiche:
    - Rimuove la selezione predefinita di applicazioni bloatware. (Vedere sotto per l'elenco completo) 
    - Disabilita la telemetria, i dati diagnostici, la cronologia delle attività, il tracciamento dell'avvio delle app e gli annunci mirati.
    - Disabilita i suggerimenti, i trucchi, i consigli e gli annunci in start, Impostazioni, Notifiche, Esplora file e sulla schermata di blocco.
    - Disabilita e rimuove la ricerca web di Bing e Cortana dalla barra di ricerca (start) di Windows
    - Disabilita Copilot di Windows. (Windows 11 only)
    - Mostra le estensioni dei tipi di file conosciuti. 
    - Nasconde la cartella oggetti 3D, musica o onedrive dal pannello laterale di Esplora file. (solo Windows 10) 
    - Disattiva il servizio widget e nasconde l'icona dalla barra delle applicazioni. 
    - Nasconde l'icona della chat (meet now) dalla barra delle applicazioni.
  </blockquote>

  #### Applicazioni che SONO rimosse per impostazione predefinita
  
  <details>
    <summary>Click to expand</summary>
    <blockquote>
      
      Microsoft bloat:
      - Clipchamp.Clipchamp  
      - Microsoft.3DBuilder  
      - Microsoft.549981C3F5F10 (Cortana app)
      - Microsoft.BingFinance  
      - Microsoft.BingFoodAndDrink 
      - Microsoft.BingHealthAndFitness
      - Microsoft.BingNews  
      - Microsoft.BingSearch* (Bing web search in Windows)
      - Microsoft.BingSports  
      - Microsoft.BingTranslator  
      - Microsoft.BingTravel   
      - Microsoft.BingWeather  
      - Microsoft.Getstarted (Cannot be uninstalled in Windows 11)
      - Microsoft.Messaging  
      - Microsoft.Microsoft3DViewer  
      - Microsoft.MicrosoftJournal
      - Microsoft.MicrosoftOfficeHub  
      - Microsoft.MicrosoftPowerBIForWindows  
      - Microsoft.MicrosoftSolitaireCollection  
      - Microsoft.MicrosoftStickyNotes  
      - Microsoft.MixedReality.Portal  
      - Microsoft.NetworkSpeedTest  
      - Microsoft.News  
      - Microsoft.Office.OneNote (Discontinued UWP version only, does not remove new MS365 versions)
      - Microsoft.Office.Sway  
      - Microsoft.OneConnect  
      - Microsoft.Print3D  
      - Microsoft.SkypeApp  
      - Microsoft.Todos  
      - Microsoft.WindowsAlarms  
      - Microsoft.WindowsFeedbackHub  
      - Microsoft.WindowsMaps  
      - Microsoft.WindowsSoundRecorder  
      - Microsoft.XboxApp (Old Xbox Console Companion App, no longer supported)
      - Microsoft.ZuneVideo  
      - MicrosoftCorporationII.MicrosoftFamily (Microsoft Family Safety)
      - MicrosoftTeams (Old personal version of MS Teams from the MS Store)
      - MSTeams (New MS Teams app)
  
      Third party bloat:
      - ACGMediaPlayer  
      - ActiproSoftwareLLC  
      - AdobeSystemsIncorporated.AdobePhotoshopExpress  
      - Amazon.com.Amazon  
      - AmazonVideo.PrimeVideo
      - Asphalt8Airborne   
      - AutodeskSketchBook  
      - CaesarsSlotsFreeCasino  
      - COOKINGFEVER  
      - CyberLinkMediaSuiteEssentials  
      - DisneyMagicKingdoms  
      - Disney 
      - Dolby  
      - DrawboardPDF  
      - Duolingo-LearnLanguagesforFree  
      - EclipseManager  
      - Facebook  
      - FarmVille2CountryEscape  
      - fitbit  
      - Flipboard  
      - HiddenCity  
      - HULULLC.HULUPLUS  
      - iHeartRadio  
      - Instagram
      - king.com.BubbleWitch3Saga  
      - king.com.CandyCrushSaga  
      - king.com.CandyCrushSodaSaga  
      - LinkedInforWindows  
      - MarchofEmpires  
      - Netflix  
      - NYTCrossword  
      - OneCalendar  
      - PandoraMediaInc  
      - PhototasticCollage  
      - PicsArt-PhotoStudio  
      - Plex  
      - PolarrPhotoEditorAcademicEdition  
      - Royal Revolt  
      - Shazam  
      - Sidia.LiveWallpaper  
      - SlingTV  
      - Speed Test  
      - Spotify  
      - TikTok
      - TuneInRadio  
      - Twitter  
      - Viber  
      - WinZipUniversal  
      - Wunderlist  
      - XING
      
      * App is removed when disabling Bing in Windows search.
  </blockquote>
  </details>
  
  #### Applicazioni che NON vengono rimosse per impostazione predefinita
  
  <details>
    <summary>Click to expand</summary>
    <blockquote>
      
      General apps that are not removed by default:
      - Microsoft.Edge (Edge browser, only removeable in the EEA)
      - Microsoft.GetHelp (Required for some Windows 11 Troubleshooters)
      - Microsoft.MSPaint (Paint 3D)
      - Microsoft.OutlookForWindows* (New mail app)
      - Microsoft.OneDrive (OneDrive consumer)
      - Microsoft.Paint (Classic Paint)
      - Microsoft.People* (Required for & included with Mail & Calendar)
      - Microsoft.ScreenSketch (Snipping Tool)
      - Microsoft.Whiteboard (Only preinstalled on devices with touchscreen and/or pen support)
      - Microsoft.Windows.Photos
      - Microsoft.WindowsCalculator
      - Microsoft.WindowsCamera
      - Microsoft.windowscommunicationsapps* (Mail & Calendar)
      - Microsoft.WindowsStore (Microsoft Store, NOTE: This app cannot be reinstalled!)
      - Microsoft.WindowsTerminal (New default terminal app in Windows 11)
      - Microsoft.YourPhone (Phone Link)
      - Microsoft.Xbox.TCUI (UI framework, removing this may break MS store, photos and certain games)
      - Microsoft.ZuneMusic (Modern Media Player)
  
      Gaming related apps that are not removed by default:
      - Microsoft.GamingApp* (Modern Xbox Gaming App, required for installing some games)
      - Microsoft.XboxGameOverlay* (Game overlay, required for some games)
      - Microsoft.XboxGamingOverlay* (Game overlay, required for some games)
      - Microsoft.XboxIdentityProvider (Xbox sign-in framework, required for some games)
      - Microsoft.XboxSpeechToTextOverlay (Might be required for some games, NOTE: This app cannot be reinstalled!)
  
      Developer related apps that are not removed by default:
      - Microsoft.PowerAutomateDesktop*
      - Microsoft.RemoteDesktop*
      - Windows.DevHome*
  
      * Can be removed by running the script with the relevant parameter. (See parameters section below)
  </blockquote>
  </details>
</details>

## Usage

> [!Warning]
> È stata posta molta attenzione nel garantire che questo script non interrompa involontariamente alcuna funzionalità del sistema operativo, ma l'uso è a vostro rischio e pericolo!

### Quick method

Scaricare ed eseguire automaticamente lo script tramite PowerShell.

1. Aprire PowerShell come amministratore.
2. Copiare e incollare il codice qui sotto in PowerShell, premere invio per eseguire lo script:

```PowerShell
& ([scriptblock]::Create((irm "https://win11debloat.raphi.re/")))
```

3. Attendere che lo script scarichi automaticamente Win11Debloat. 
4. Si aprirà una nuova finestra di PowerShell che mostrerà il menu Win11Debloat. Selezionate la default mode oppure la custom mode per continuare. 
5. Leggere attentamente e seguire le istruzioni a video.

Questo metodo supporta i [parametri](#parametri). Per utilizzare i parametri è sufficiente eseguire lo script come spiegato sopra, ma aggiungendo i parametri alla fine con degli spazi intermedi. Esempio:

```PowerShell
& ([scriptblock]::Create((irm "https://win11debloat.raphi.re/"))) -RunDefaults -Silent
```

### Traditional method

Scaricare ed eseguire manualmente lo script.

1. [Scaricate l'ultima versione dello script](https://github.com/Raphire/Win11Debloat/archive/master.zip) ed estraete il file .ZIP nella posizione desiderata. 
2. Passare alla cartella Win11Debloat
3. Doppio click sul file `Run.bat` per avviare lo script. NOTA: se la finestra della console si chiude immediatamente e non succede nulla, provare il metodo avanzato riportato di seguito.
4. Accettate il prompt UAC di Windows per eseguire lo script come amministratore; necessario per il funzionamento dello script. 
5. Si aprirà una nuova finestra di PowerShell che mostrerà il menu Win11Debloat. Selezionate la default mode oppure la custom mode per continuare. 
6. Leggere attentamente e seguire le istruzioni a video.

### Advanced method

Scaricare manualmente lo script ed eseguirlo tramite PowerShell. Consigliato solo agli utenti esperti.

1. [Scaricate l'ultima versione dello script](https://github.com/Raphire/Win11Debloat/archive/master.zip) ed estraete il file .ZIP nella posizione desiderata. 
2. Aprire PowerShell come amministratore.
3. Abilitare l'esecuzione di PowerShell immettendo il seguente comando:

```PowerShell
Set-ExecutionPolicy Unrestricted -Scope Process
```

4. In PowerShell, navigare nella directory in cui sono stati estratti i file.  Esempio: `cd c:\Win11Debloat`
5. Ora eseguite lo script immettendo il seguente comando:

```PowerShell
.\Win11Debloat.ps1
```

6. Si aprirà una nuova finestra di PowerShell che mostrerà il menu Win11Debloat. Selezionate la default mode oppure la custom mode per continuare. 
7. Leggere attentamente e seguire le istruzioni a video.

Questo metodo supporta i [parametri](#parameters). Per utilizzare i parametri è sufficiente eseguire lo script come spiegato sopra, ma aggiungendo i parametri alla fine con degli spazi intermedi. Esempio:

```PowerShell
.\Win11Debloat.ps1 -RemoveApps -DisableBing -Silent
```

### Parameters

Il quick method e l'advanced method supportano parametri per adattare il comportamento dello script alle vostre esigenze. Di seguito è riportato un elenco di tutti i parametri supportati e delle loro funzioni.

| Parametri | Descrizione |
| :-------: | ----------- |
| -Silent                            |    Sopprime tutte le richieste interattive, in modo che lo script venga eseguito senza richiedere alcun input da parte dell'utente. |
| -Sysprep                           |    Esegue lo script in modalità Sysprep. Tutte le modifiche saranno applicate al profilo utente predefinito di Windows e avranno effetto solo sui nuovi account utente. |
| -RunDefaults                       |    Esegue lo script con le impostazioni di default |
| -RemoveApps                        |    Rimuove la selezione predefinita di applicazioni bloatware. |
| -RemoveAppsCustom                  |    Rimuove tutte le applicazioni dal file 'CustomAppsList'. IMPORTANTE: eseguire lo script con il parametro `-RunAppConfigurator` per creare prima questo file. Se questo file non esiste, non verrà rimossa alcuna applicazione! |
| -RunAppConfigurator                |    Esegue il configuratore di app per creare un file 'CustomAppsList'. Eseguire lo script con il parametro  `-RemoveAppsCustom` per rimuovere queste applicazioni. |
| -RemoveCommApps                    |    Rimuove le app Posta, Calendario, e Persone |
| -RemoveW11Outlook                  |    Rimuove Outlook (NEW). |
| -RemoveDevApps                     |    Rimuove le applicazioni legate agli sviluppatori, come Remote Desktop, DevHome e Power Automate.. |
| -RemoveGamingApps                  |    Rimuove l'app Xbox e la Gamebar Xbox. |
| -ForceRemoveEdge                   |    Rimuove forzatamente Microsoft Edge; questa opzione lascia installati i componenti Core, WebView e Update per garantire la compatibilità. NON RACCOMANDATA!! |
| -DisableDVR                        |    Disattiva la funzione di registrazione di gioco/schermo di Xbox e interrompere i popup di sovrapposizione del gioco. |
| -ClearStart                        |    Rimuove tutte le app pinnate nel menu start per l'utente corrente (solo Windows 11 update 22H2 o successivo) |
| -ClearStartAllUsers                |    Rimuove tutte le app pinnate nel menu start  per tutti gli utenti esistenti e nuovi. (solo Windows 11 update 22H2 o successivo) |
| -DisableTelemetry                  |    Disattiva la telemetria, i dati diagnostici e gli annunci mirati.    |
| -DisableBing                       |    Disattiva e rimuove la ricerca web di Bing, Bing AI e Cortana nella ricerca di Windows. |
| -DisableSuggestions                |    Disabilita i suggerimenti, i trucchi, i consigli e gli annunci in start, Impostazioni, Notifiche, Esplora file. |
| <pre>-DisableLockscreenTips</pre>  |    Disabilita i suggerimenti e i trucchi sulla schermata di blocco. |
| -RevertContextMenu                 |    Ripristina il vecchio menu contestuale in stile Windows 10. (solo Windows 11) |
| -ShowHiddenFolders                 |    Mostra file, cartelle e unità nascoste. |
| -ShowKnownFileExt                  |    Mostra le estensioni dei tipi di file conosciuti. |
| -HideDupliDrive                    |    Nasconde le voci delle unità rimovibili duplicate dal pannello laterale di Esplora file, in modo che rimanga solo la voce sotto "Questo PC". |
| -TaskbarAlignLeft                  |    Allinea le icone della barra delle applicazioni a sinistra. (solo Windows 11) |
| -HideSearchTb                      |    Nasconde l'icona di ricerca dalla barra delle applicazioni. (Solo Windows 11) |
| -ShowSearchIconTb                  |    Mostra l'icona di ricerca dalla barra delle applicazioni. (Solo Windows 11) |
| -ShowSearchLabelTb                 |    Mostra l'icona di ricerca con etichetta sulla barra delle applicazioni. (solo Windows 11) |
| -ShowSearchBoxTb                   |    Mostra la casella di ricerca sulla barra delle applicazioni. (solo Windows 11) |
| -HideTaskview                      |    Nasconde il pulsante `Visualizzazione attività` dalla barra delle applicazioni. (Solo Windows 11) |
| -HideChat                          |    Nasconde l'icona chat (meet now) dalla barra delle applicazioni. |
| -DisableWidgets                    |    Disabilita il servizio widget e nasconde l'icona del widget (notizie e interessi) dalla barra delle applicazioni. |
| -DisableCopilot                    |    Disablilita Windows copilot. (solo Windows 11) |
| -DisableRecall                     |    Disabilita gli snapshot di Windows Recall. (solo per Windows 11) |
| -HideGallery                       |    Nasconde la sezione `galleria` dal pannello laterale di Esplora file. (solo Windows 11)  |
| -HideOnedrive                      |    Nasconde la cartella onedrive dal pannello laterale di Esplora file. (solo Windows 10) |
| -Hide3dObjects                     |    Nasconde la cartella degli oggetti 3D sotto 'Questo pc' in Esplora file. (solo Windows 10) |
| -HideMusic                         |    Nasconde la cartella musica sotto 'Questo pc' in Esplora file. (solo Windows 10) |
| -HideIncludeInLibrary              |    Nasconde l'opzione 'Includi in libreria' nel menu contestuale. (solo per Windows 10) |
| -HideGiveAccessTo                  |    Nasconde l'opzione 'Dai accesso a' nel menu contestuale. (solo per Windows 10) |
| -HideShare                         |    Nasconde l'opzione 'Condividi' nel menu contestuale. (solo per Windows 10) |
