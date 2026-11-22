$script:Sources = @(
    [pscustomobject]@{ Label = 'Microsoft · Desempenho do Windows'; Url = 'https://support.microsoft.com/pt-br/windows/experience/performance-optimization/tips-to-improve-pc-performance-in-windows' }
    [pscustomobject]@{ Label = 'Microsoft · Otimizações para jogos em janela'; Url = 'https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11' }
    [pscustomobject]@{ Label = 'NVIDIA · Latência do sistema e Reflex'; Url = 'https://www.nvidia.com/en-gb/geforce/guides/system-latency-optimization-guide/' }
    [pscustomobject]@{ Label = 'NVIDIA · Referência de configurações 3D'; Url = 'https://www.nvidia.com/content/Control-Panel-Help/vLatest/pt-br/mergedProjects/nv3dPTB/Manage_3D_Settings_%28reference%29.htm' }
    [pscustomobject]@{ Label = 'NVIDIA · Super-resolução e geração de quadros'; Url = 'https://developer.nvidia.com/rtx/dlss' }
    [pscustomobject]@{ Label = 'AMD · Anti-Lag e Anti-Lag 2'; Url = 'https://www.amd.com/en/products/software/adrenalin/radeon-software-anti-lag.html' }
    [pscustomobject]@{ Label = 'AMD · Super-resolução FSR'; Url = 'https://www.amd.com/en/products/graphics/technologies/fidelityfx/super-resolution.html' }
    [pscustomobject]@{ Label = 'AMD · Configurar FreeSync'; Url = 'https://www.amd.com/en/resources/support-articles/faqs/DH3-013.html' }
    [pscustomobject]@{ Label = 'AMD · Métricas de desempenho'; Url = 'https://www.amd.com/en/resources/support-articles/faqs/DH3-038.html' }
    [pscustomobject]@{ Label = 'Steam · Monitor de desempenho'; Url = 'https://store.steampowered.com/news/posts/?enddate=1752684106' }
    [pscustomobject]@{ Label = 'Steam · Gerenciar downloads'; Url = 'https://help.steampowered.com/pt-br/faqs/view/71AB-698D-57EB-178C' }
    [pscustomobject]@{ Label = 'Epic Games · Guia competitivo de 2026'; Url = 'https://store.epicgames.com/news/fortnite-on-pc-best-settings-for-competitive-play-in-2026?lang=pt-BR' }
    [pscustomobject]@{ Label = 'Epic Games · Modo Desempenho'; Url = 'https://www.epicgames.com/help/c-34254770/c-37371353/a20197720?lang=pt-BR' }
    [pscustomobject]@{ Label = 'Epic Games · FPS baixo no PC'; Url = 'https://www.epicgames.com/help/c-34254770/c-38015632/a25544495?lang=pt-BR' }
    [pscustomobject]@{ Label = 'Epic Games · V-Sync e limite de FPS'; Url = 'https://www.epicgames.com/help/c-34254770/c-37371353/a17266354?lang=pt-BR' }
    [pscustomobject]@{ Label = 'Epic Games · Super-resolução'; Url = 'https://www.epicgames.com/help/c-34254770/c-38015632/a20987201?lang=pt-BR' }
    [pscustomobject]@{ Label = 'Epic Games · Latência e ping'; Url = 'https://www.epicgames.com/help/c-34254770/c-Trending_0/a22355516?lang=pt-BR' }
    [pscustomobject]@{ Label = 'Microsoft · Aplicativos de inicialização'; Url = 'https://support.microsoft.com/pt-br/windows/experience/startup-boot/configure-startup-applications-in-windows' }
    [pscustomobject]@{ Label = 'Microsoft · Taxa de atualização'; Url = 'https://support.microsoft.com/pt-br/windows/hardware/display-graphics/change-the-refresh-rate-on-your-monitor-in-windows' }
    [pscustomobject]@{ Label = 'Microsoft · Proteção do Sistema'; Url = 'https://support.microsoft.com/pt-br/windows/experience/backup-recovery/system-protection' }
)

function New-OptimizerTweak {
    param(
        [string]$Id,
        [string]$Title,
        [ValidateSet('Jogos','Fortnite','Windows','GPU','Entrada','Rede','Debloat','Hardware')][string]$Category,
        [ValidateSet('Auto','Windows','Manual','Link')][string]$Mode,
        [string]$Summary,
        [string]$Instructions,
        [string]$Target = '',
        [switch]$Featured
    )

    [pscustomobject]@{
        Id = $Id
        Title = $Title
        Category = $Category
        Summary = $Summary
        Instructions = $Instructions
        Mode = $Mode
        Target = $Target
        Featured = [bool]$Featured
    }
}

$script:Tweaks = @(
    New-OptimizerTweak gamebenchmark 'Medir desempenho antes e depois' Jogos Manual `
        'Ajuda a confirmar se o ajuste melhorou a fluidez e a descartar variações causadas pela cena.' `
        'Use o benchmark do jogo ou percorra o mesmo trecho. Faça três medições curtas por configuração, com a mesma resolução e o mesmo limite. Compare FPS médio e, se disponíveis, 1% low ou tempos de quadro. Mude uma opção por vez.' -Featured

    New-OptimizerTweak gamefpscap 'Definir um limite de FPS sustentável' Jogos Manual `
        'Um limite que o PC consiga sustentar pode reduzir oscilações e reservar margem para cenas pesadas.' `
        'Nas opções de vídeo, teste um teto próximo da taxa do monitor. Em uma tela de 60 Hz, 60 FPS é um ponto de partida. Compare um teto maior se o PC sustentar a taxa e você priorizar resposta. Use um limitador por vez e confira fluidez e cortes de imagem.' -Featured

    New-OptimizerTweak gamepreset 'Começar com qualidade gráfica Média ou Baixa' Jogos Manual `
        'Reduz trabalho de renderização quando as opções no máximo deixam o jogo pesado.' `
        'Em Vídeo ou Gráficos, escolha a predefinição Média. Se o FPS continuar instável, teste Baixa. Suba uma opção visual de cada vez até encontrar o equilíbrio desejado.' -Featured

    New-OptimizerTweak gamesuperres 'Usar super-resolução quando a GPU limita' Jogos Manual `
        'Reconstrói a imagem de saída a partir de menos pixels renderizados, aliviando a GPU.' `
        'Nas opções gráficas, procure FSR, XeSS, TSR ou DLSS Super Resolution em uma GeForce RTX compatível. Escolha um único método disponível e comece no modo Qualidade. Compare legibilidade, estabilidade e FPS.' -Featured

    New-OptimizerTweak gamelowlatency 'Ativar baixa latência integrada ao jogo' Jogos Manual `
        'Pode reduzir a fila de renderização em jogos e equipamentos compatíveis.' `
        'No menu do jogo, procure NVIDIA Reflex em uma GeForce compatível ou AMD Radeon Anti-Lag 2 em uma Radeon compatível. Ative a opção integrada oferecida pelo título e compare no mesmo trecho de jogo.' -Featured

    New-OptimizerTweak gameframetimes 'Acompanhar picos no tempo de quadro' Jogos Manual `
        'Mostra engasgos que podem passar despercebidos no FPS médio.' `
        'Use o gráfico de desempenho interno do jogo ou as métricas da Steam, NVIDIA ou AMD quando disponíveis. Procure picos em milissegundos e anote em que trecho aparecem. Desative a sobreposição após o diagnóstico se ela interferir no jogo.'

    New-OptimizerTweak gamedynamicres 'Testar resolução dinâmica' Jogos Manual `
        'Ajusta a escala de renderização em cenas mais pesadas para tentar manter a taxa de quadros alvo.' `
        'Se o menu gráfico oferecer Resolução dinâmica, selecione uma meta de FPS sustentável e compare com escala fixa na mesma cena. Mantenha apenas se a nitidez permanecer aceitável.'

    New-OptimizerTweak gameraytracing 'Reduzir efeitos de ray tracing' Jogos Manual `
        'Recupera margem de desempenho quando reflexos, sombras ou iluminação traçados saturam a GPU.' `
        'Em Gráficos, desligue o ray tracing ou reduza sua qualidade. Compare uma área com iluminação e reflexos pesados. Reative os efeitos de que mais gosta se ainda houver margem.'

    New-OptimizerTweak gameframegen 'Comparar geração de quadros desligada' Jogos Manual `
        'Quadros interpolados suavizam o movimento. A resposta aos comandos ainda depende da taxa renderizada pelo jogo.' `
        'Se houver Geração de quadros, compare ligado e desligado mantendo a mesma escala de resolução. Em jogos competitivos, observe a resposta do mouse. Em jogos solo, compare fluidez e artefatos durante movimentos rápidos.'

    New-OptimizerTweak gamevrr 'Ativar frequência variável em telas compatíveis' Jogos Manual `
        'Acompanha a entrega de quadros na faixa VRR da tela e ajuda a reduzir cortes e trepidações.' `
        'Ative Adaptive-Sync no menu físico da tela. Em Radeon compatível, confira FreeSync nas configurações de Exibição do AMD Software. Em GeForce compatível, verifique Configurar G-SYNC no Painel NVIDIA. Teste uma taxa dentro da faixa do monitor.'

    New-OptimizerTweak gamevsync 'Comparar V-Sync conforme o tipo de jogo' Jogos Manual `
        'Reduz cortes horizontais quando ligado. Em alguns cenários pode aumentar o atraso entre o comando e a imagem.' `
        'Em Vídeo, compare a movimentação de câmera com V-Sync ligado e desligado em uma mesma cena. Se usar VRR, confira o procedimento do fabricante. Em jogos competitivos, observe também a resposta aos comandos.'

    New-OptimizerTweak gamemouseinput 'Usar entrada bruta do mouse' Jogos Manual `
        'Lê contagens do mouse diretamente em jogos que expõem Raw Input e ajuda a manter a mira consistente.' `
        'Em Controles ou Mouse, ligue Entrada bruta ou Raw Input, se houver essa opção. Mantenha o mesmo DPI e verifique se a sensibilidade dentro do jogo continua adequada.'

    New-OptimizerTweak gamecontrollerdeadzone 'Calibrar a zona morta do controle' Jogos Manual `
        'Uma zona morta menor pode fazer o jogo reagir a movimentos mais leves do analógico.' `
        'Em Controles, reduza a zona morta em pequenos passos. Solte o analógico em uma área de treino. Se a câmera ou o personagem se mover sozinho, suba um passo até eliminar a deriva.'

    New-OptimizerTweak gamesteamoverlay 'Testar sem a sobreposição da Steam' Jogos Manual `
        'Ajuda a isolar conflitos de apresentação ou travamentos associados à sobreposição.' `
        'Na Biblioteca Steam, abra Propriedades do jogo → Geral e desligue a sobreposição para esse título. Reinicie o jogo e compare. O menu Shift+Tab e recursos ligados à sobreposição ficam indisponíveis nessa condição.'

    New-OptimizerTweak gamedlsteam 'Impedir downloads da Steam durante jogos' Jogos Manual `
        'Evita que downloads concorram com o jogo por rede e disco.' `
        'Em Steam → Configurações → Downloads, deixe desativado Permitir downloads enquanto joga. Confira em Propriedades → Atualizações se um jogo tem uma preferência própria.'

    New-OptimizerTweak gameverify 'Verificar a instalação de jogos Steam' Jogos Link `
        'Pode reparar arquivos ausentes ou corrompidos quando um jogo apresenta falhas recorrentes.' `
        'Com o jogo fechado, abra Steam → Biblioteca → Propriedades → Arquivos instalados → Verificar integridade dos arquivos. Aguarde o fim antes de testar o jogo.' 'https://help.steampowered.com/pt-br/faqs/view/0C48-FCBD-DA71-93EB'

    New-OptimizerTweak gamewindowmode 'Comparar tela cheia e janela sem bordas' Jogos Manual `
        'O modo de apresentação pode afetar fluidez, resposta da janela e compatibilidade com sobreposições.' `
        'Em Vídeo, compare Tela cheia e Janela sem bordas. Preserve resolução, V-Sync e limite de FPS nas duas rodadas. Reabra o jogo se o menu solicitar.'

    New-OptimizerTweak gamebackgroundfps 'Limitar FPS quando o jogo perde foco' Jogos Manual `
        'Reduz a carga de um jogo minimizado ou em segundo plano enquanto outro aplicativo está em uso.' `
        'Procure Limite de FPS em segundo plano no jogo. Se disponível, selecione um teto baixo para a janela fora de foco e confira se a taxa normal volta ao retomar a partida.'

    New-OptimizerTweak gamesteammetrics 'Ativar métricas da Steam para comparar ajustes' Jogos Manual `
        'Mostra FPS, quadro gerado e uso de recursos em jogos compatíveis, conforme o nível escolhido.' `
        'Em Steam → Configurações → Em jogo, procure o monitor de desempenho e selecione o nível que inclui CPU, GPU e memória. Use durante os testes e reduza os detalhes para as partidas normais.'

    New-OptimizerTweak gamemode 'Ativar Modo de Jogo do Windows' Windows Auto `
        'Faz o Windows reconhecer a sessão de jogo e reduzir certas interrupções associadas a tarefas em segundo plano.' `
        'Ajuste de Registro no perfil atual. Reabra o jogo após aplicar. A configuração está em Configurações → Jogos → Modo de Jogo.' -Featured

    New-OptimizerTweak dvr 'Desativar capturas do Game DVR' Windows Auto `
        'Desativa a captura do Windows para evitar o trabalho de gravação de clipes durante o jogo.' `
        'Ajuste de Registro no perfil atual. A gravação em segundo plano e outros controles de captura da Xbox Game Bar podem ficar indisponíveis. Reabra o jogo após aplicar.' -Featured

    New-OptimizerTweak capturesaudio 'Desativar áudio das capturas' Windows Auto `
        'Desliga a inclusão de áudio em capturas de vídeo da Game Bar que continuam habilitadas.' `
        'Ajuste de Registro no perfil atual. O volume e a saída de áudio do jogo seguem as configurações do Windows. Reabra a Game Bar após aplicar.'

    New-OptimizerTweak transparency 'Desligar transparência do Windows' Windows Auto `
        'Simplifica a composição visual do desktop. O efeito é mais perceptível no próprio Windows.' `
        'Ajuste de Registro no perfil atual. A alteração remove a transparência de elementos como o menu Iniciar e a barra de tarefas. Saia e entre na conta se o visual não mudar.'

    New-OptimizerTweak menudelay 'Definir submenus em 150 ms' Windows Auto `
        'Define em 150 ms a espera para abrir submenus que usam a configuração do Windows.' `
        'Ajuste de Registro no perfil atual. Saia e entre na conta para atualizar os aplicativos que leem esse valor ao iniciar. O ajuste atua na interface do Windows.'

    New-OptimizerTweak snapoff 'Desativar encaixe de janelas' Windows Auto `
        'Desliga o encaixe automático de janelas, incluindo os layouts associados quando disponíveis.' `
        'Ajuste de Registro no perfil atual. Use se costuma acionar o encaixe sem querer ao mover janelas. Saia e entre na conta se necessário.'

    New-OptimizerTweak powerhigh 'Testar plano Alto desempenho' Windows Auto `
        'É uma alternativa para comparar resposta sob carga, com possível aumento de consumo e calor.' `
        'Ative se o plano estiver disponível e compare com Equilibrado na mesma cena. Monitore temperatura e ruído antes de decidir qual usar regularmente.'

    New-OptimizerTweak powerbalanced 'Selecionar plano Equilibrado' Windows Auto `
        'Permite escalonar consumo e frequência conforme a carga e serve de base para comparar outros planos.' `
        'Selecione Equilibrado para usar a política padrão de energia. Compare FPS e consistência com Alto desempenho antes de escolher seu plano de longo prazo.'

    New-OptimizerTweak winanimations 'Desligar animações da interface' Windows Windows `
        'Encurta transições de janelas e menus e deixa a interface do Windows mais ágil.' `
        'Desative Efeitos de animação na página de efeitos visuais. Em algumas edições do Windows 10, a opção fica em Facilidade de Acesso → Tela.' 'ms-settings:easeofaccess-visualeffects'

    New-OptimizerTweak acthours 'Definir horário ativo do Windows Update' Windows Windows `
        'Reduz o risco de reinício automático durante sua janela habitual de partidas.' `
        'Em Windows Update → Opções avançadas → Horário ativo, selecione ajuste manual e defina o intervalo em que costuma jogar.' 'ms-settings:windowsupdate'

    New-OptimizerTweak donotdisturb 'Silenciar notificações em jogos' Windows Windows `
        'Evita banners e sons de aplicativos durante partidas em tela cheia.' `
        'Em Sistema → Notificações, configure Não incomodar para ativar automaticamente ao jogar, se a regra estiver disponível. No Windows 10, procure Assistente de foco.' 'ms-settings:notifications'

    New-OptimizerTweak modeeco 'Testar modo de eficiência em apps' Windows Manual `
        'Reduz a prioridade de um processo de fundo escolhido no Windows 11, com possível perda de velocidade nesse app.' `
        'Abra o Gerenciador de Tarefas com Ctrl+Shift+Esc. Em Processos, clique com o botão direito sobre um aplicativo secundário conhecido e teste Modo de eficiência quando disponível. Use apenas em tarefas que podem esperar.'

    New-OptimizerTweak gamegpu 'Selecionar a GPU de alto desempenho por jogo' GPU Windows `
        'Seleciona a GPU de alto desempenho quando o Windows detecta mais de uma opção.' `
        'Em Gráficos, selecione o jogo ou adicione o executável pela opção Procurar. Abra Opções → Alto desempenho, confira a GPU exibida e salve. Use esta opção se o Windows listar GPUs diferentes.' 'ms-settings:display-advancedgraphics'

    New-OptimizerTweak hags 'Comparar agendamento de GPU por hardware' GPU Windows `
        'Muda parte do agendamento da GPU. FPS e fluidez podem variar com jogo e driver.' `
        'Em Sistema → Tela → Gráficos → Configurações padrão, procure Agendamento de GPU com aceleração de hardware. Altere, reinicie o Windows e compare. Se não aparecer, o sistema não expõe esse controle.' 'ms-settings:display-advancedgraphics'

    New-OptimizerTweak flipmodel 'Otimizar jogos em janela' GPU Windows `
        'Pode reduzir latência de apresentação em jogos DirectX 10/11 compatíveis no Windows 11.' `
        'Em Sistema → Tela → Gráficos → Configurações padrão, ative Otimizações para jogos em janela. Reabra o jogo e compare em modo sem bordas. O efeito depende da API usada pelo jogo.' 'ms-settings:display-advancedgraphics'

    New-OptimizerTweak nvdriver 'Atualizar o driver GeForce Game Ready' GPU Link `
        'Drivers oficiais compatíveis podem incluir correções para falhas gráficas, estabilidade e desempenho.' `
        'Para uma NVIDIA GeForce, selecione a série e o modelo indicados no scanner, além da sua versão do Windows. Consulte as notas antes de instalar e reinicie quando solicitado.' 'https://www.nvidia.com/pt-br/drivers/'

    New-OptimizerTweak amddriver 'Atualizar o driver AMD Radeon' GPU Link `
        'Uma versão compatível pode corrigir falhas gráficas e melhorar o suporte a jogos.' `
        'Para uma Radeon, abra o site oficial, selecione seu modelo e sistema ou use a detecção da AMD. Consulte as notas do pacote compatível. Em notebooks, confira também o suporte do fabricante do equipamento.' 'https://www.amd.com/en/support/download/drivers.html'

    New-OptimizerTweak inteldriver 'Atualizar o driver Intel Arc' GPU Link `
        'Drivers compatíveis incluem correções gráficas e melhorias de suporte a jogos.' `
        'Para Intel Arc, verifique o modelo no scanner e compare com a lista de compatibilidade da Intel. Em PCs pré-montados e notebooks, confira primeiro o driver oferecido pelo fabricante do PC.' 'https://www.intel.com/content/www/us/en/download/785597/intel-arc-graphics-windows.html'

    New-OptimizerTweak nvpstate 'Testar desempenho máximo por jogo' GPU Manual `
        'Reduz quedas de clock da GPU durante o jogo, com possível aumento de temperatura e consumo.' `
        'No Painel de Controle NVIDIA, abra Gerenciar configurações 3D → Configurações de programa. Selecione o jogo e teste Preferir desempenho máximo no modo de gerenciamento da energia desse perfil.'

    New-OptimizerTweak nvtexture 'Testar filtragem de texturas voltada a FPS' GPU Manual `
        'Troca parte da qualidade da filtragem por menor custo em jogos compatíveis.' `
        'No Painel de Controle NVIDIA, abra Gerenciar configurações 3D → Configurações de programa e selecione o jogo. Em Filtragem de textura — Qualidade, compare Alto desempenho com o padrão.'

    New-OptimizerTweak shadercache 'Manter cache de shaders ativo' GPU Manual `
        'Reaproveita compilações de shaders e pode reduzir travadas em sessões posteriores.' `
        'No Painel de Controle NVIDIA, abra Gerenciar configurações 3D → Configurações globais → Tamanho do cache do criador de sombras. Use Padrão do driver se estiver Desativado. Um driver novo pode exigir recompilação.'

    New-OptimizerTweak nvlowlatency 'Usar baixa latência em jogos sem Reflex' GPU Manual `
        'Limita a fila de renderização em jogos compatíveis que não oferecem NVIDIA Reflex.' `
        'No Painel de Controle NVIDIA → Gerenciar configurações 3D → Configurações de programa, escolha um jogo DX9 ou DX11 sem Reflex e teste Modo de baixa latência → Ligado.'

    New-OptimizerTweak shadowplay 'Desativar Instant Replay da NVIDIA' GPU Manual `
        'Interrompe a captura contínua mantida pelo Instant Replay. Isso libera o trabalho associado à gravação.' `
        'Se usa o NVIDIA App, pressione Alt+Z e escolha Instant Replay → Desativar. Alt+Z só funciona quando a sobreposição está disponível e habilitada.'

    New-OptimizerTweak nvoverlay 'Desativar sobreposição NVIDIA' GPU Manual `
        'Remove uma camada de captura e métricas se ela interferir na apresentação ou apresentar conflito.' `
        'No NVIDIA App, abra Configurações e desligue NVIDIA Overlay. O atalho Alt+Z, os clipes e as métricas da sobreposição deixam de funcionar enquanto ela estiver desligada.'

    New-OptimizerTweak refresh 'Usar a maior taxa de atualização' Entrada Windows `
        'Atualiza a imagem mais vezes por segundo em monitores compatíveis e pode melhorar a resposta visual.' `
        'Abra Sistema → Tela → Tela avançada e selecione o monitor que usa para jogar. Teste a maior taxa oferecida na resolução desejada, se a tela estiver configurada abaixo desse valor.' 'ms-settings:display-advanced' -Featured

    New-OptimizerTweak mouseaccel 'Desativar aceleração do ponteiro' Entrada Auto `
        'Padroniza o movimento do ponteiro em aplicações que usam a curva do Windows. Jogos com entrada bruta podem ignorar o ajuste.' `
        'Ajuste de Registro no perfil atual. Se o ponteiro continuar com o comportamento anterior, saia e entre na conta. Ele altera a curva do mouse, sem alterar o DPI.'

    New-OptimizerTweak gsync 'Configurar G-SYNC quando disponível' Entrada Manual `
        'Sincroniza a atualização do monitor com os quadros do jogo dentro da faixa compatível e reduz cortes de imagem.' `
        'Ative Adaptive Sync no menu do monitor compatível. No Painel de Controle NVIDIA → Monitor → Configurar G-SYNC, marque G-SYNC, escolha o monitor e aplique. Teste durante uma partida.'

    New-OptimizerTweak pollrate 'Ajustar a frequência do mouse' Entrada Manual `
        'Uma taxa de 1.000 Hz reduz o intervalo nominal de relatórios para 1 ms. Taxas maiores podem aumentar carga de CPU.' `
        'No software oficial do mouse, selecione 1.000 Hz se compatível. Se houver travadas ao mover o mouse, compare 500 Hz. Salve o perfil no dispositivo se houver essa opção.'

    New-OptimizerTweak mouseusb 'Aproximar o receptor do mouse' Entrada Manual `
        'Reduz a chance de interferência ou perda de sinal em periféricos sem fio.' `
        'Posicione o receptor USB perto do mouse, de preferência usando a extensão incluída se houver. Teste outra porta e afaste o receptor de hubs ou cabos que causem interferência.'

    New-OptimizerTweak controllerusb 'Testar controle por cabo' Entrada Manual `
        'Ajuda a descartar interferência e problemas de bateria quando o controle sem fio apresenta comandos intermitentes.' `
        'Se o controle aceitar USB, conecte-o com um cabo de dados e compare com o modo sem fio. Use o mesmo perfil no jogo e teste em uma sessão curta.'

    New-OptimizerTweak stickykeys 'Evitar ativação acidental de Teclas de Aderência' Entrada Windows `
        'Evita que o atalho de acessibilidade abra uma caixa de diálogo durante uma sequência de comandos.' `
        'Em Acessibilidade → Teclado, abra Teclas de Aderência e desative apenas o atalho de pressionar Shift cinco vezes, caso você não o use. Preserve a função se ela faz parte do seu modo de jogar.' 'ms-settings:easeofaccess-keyboard'

    New-OptimizerTweak filterkeys 'Revisar o atalho de Teclas de Filtro' Entrada Windows `
        'Evita ativar por engano o filtro de toques breves ou repetidos ao segurar Shift durante o jogo.' `
        'Em Acessibilidade → Teclado → Teclas de Filtro, desative o atalho de manter Shift direito pressionado, caso não precise dele. Mantenha as opções de acessibilidade que você utiliza.' 'ms-settings:easeofaccess-keyboard'

    New-OptimizerTweak monitoroverdrive 'Ajustar resposta do monitor' Entrada Manual `
        'O overdrive pode reduzir rastros de movimento. O nível mais forte pode gerar halos visíveis.' `
        'No menu físico do monitor, procure Overdrive, Tempo de resposta ou equivalente. Teste Normal e Rápido no jogo e mantenha o modo mais limpo dentro da faixa de atualização utilizada.'

    New-OptimizerTweak wired 'Preferir cabo Ethernet' Rede Manual `
        'Pode reduzir interrupções e variação de ping causadas por interferência no Wi-Fi.' `
        'Conecte um cabo Ethernet do roteador ao PC. Confira em Configurações → Rede e Internet se Ethernet aparece como conectado. Compare o ping e a perda dentro do jogo que costuma jogar.'

    New-OptimizerTweak wifiband 'Comparar bandas do Wi-Fi' Rede Manual `
        'A faixa de 5 GHz costuma ter menos interferência a curta distância. A de 2,4 GHz pode funcionar melhor longe do roteador.' `
        'Se não puder usar cabo, conecte-se à rede de 5 GHz perto do roteador e compare com 2,4 GHz. Use as estatísticas de rede do jogo para conferir perda e estabilidade, além da média de ping.'

    New-OptimizerTweak pauseepicdl 'Pausar downloads da Epic durante partidas' Rede Manual `
        'Evita que atualizações de outros jogos concorram com a partida por rede e disco.' `
        'Abra o gerenciador de downloads da Epic antes de jogar e pause a fila de transferências. Retome os downloads quando terminar a sessão.'

    New-OptimizerTweak pausecloud 'Pausar sincronização do OneDrive' Rede Manual `
        'Evita que sincronizações pesadas disputem a conexão e o disco com o jogo.' `
        'Na área de notificação, abra o OneDrive → engrenagem → Pausar sincronização → 2 horas. Retome após a sessão se ainda estiver pausado.'

    New-OptimizerTweak deliveryoptimization 'Desligar downloads de outros PCs' Rede Windows `
        'Evita o compartilhamento de atualizações por pares e o tráfego associado a esse recurso.' `
        'Em Windows Update → Opções avançadas → Otimização de Entrega, desligue Permitir downloads de outros PCs. O Windows Update continuará funcionando.' 'ms-settings:delivery-optimization'

    New-OptimizerTweak qos 'Testar QoS no roteador' Rede Manual `
        'Pode controlar aumentos de ping quando outros dispositivos ocupam o upload ou download.' `
        'Se o roteador oferecer QoS, SQM ou gerenciamento de filas, siga o manual do equipamento. Compare o ping no seu jogo com a conexão ocupada antes e depois. Use as configurações anteriores se o resultado piorar.'

    New-OptimizerTweak taskbarwidgets 'Ocultar Widgets da barra de tarefas' Debloat Auto `
        'Remove o acesso aos Widgets da barra do Windows 11. O efeito principal é reduzir distrações na interface.' `
        'Ajuste de Registro no perfil atual do Windows 11. O recurso pode continuar instalado. Saia e entre na conta se o botão permanecer visível.'

    New-OptimizerTweak taskbarsearch 'Ocultar busca da barra de tarefas' Debloat Auto `
        'Libera espaço na barra de tarefas. A pesquisa pelo menu Iniciar continua disponível.' `
        'Ajuste de Registro no perfil atual. Use o menu Iniciar ou Win+S para pesquisar. Saia e entre na conta se a barra não se atualizar.'

    New-OptimizerTweak taskbarview 'Ocultar botão de Visão de Tarefas' Debloat Auto `
        'Reduz elementos na barra, preservando o acesso às áreas de trabalho virtuais pelo atalho Win+Tab.' `
        'Ajuste de Registro no perfil atual. Saia e entre na conta se a barra não se atualizar. O efeito é visual.'

    New-OptimizerTweak startup 'Reduzir aplicativos de inicialização' Debloat Windows `
        'Impede que aplicativos escolhidos ocupem memória, CPU e disco desde o início da sessão.' `
        'Abra Aplicativos → Inicialização e desative programas opcionais que reconhece e não usa ao jogar. Preserve segurança, áudio e utilitários necessários ao seu equipamento.' 'ms-settings:startupapps' -Featured

    New-OptimizerTweak backgroundapps 'Limitar apps em segundo plano' Debloat Windows `
        'Reduz notificações e atividade de aplicativos de que você abre mão durante o jogo.' `
        'Em Aplicativos instalados, selecione um app opcional → Opções avançadas → Permissões em segundo plano → Nunca, quando disponível. Aplicativos desktop controlam essa opção no próprio programa.' 'ms-settings:appsfeatures'

    New-OptimizerTweak uninstallapps 'Desinstalar programas sem uso' Debloat Windows `
        'Libera armazenamento e pode remover tarefas de fundo dos programas selecionados.' `
        'Em Aplicativos instalados, ordene por tamanho. Abra o menu de um programa conhecido que você já não usa e escolha Desinstalar. Confira se existem dados locais que deseja guardar.' 'ms-settings:appsfeatures'

    New-OptimizerTweak optionalfeatures 'Revisar recursos opcionais' Debloat Windows `
        'Permite recuperar espaço removendo componentes instalados que você identificou como dispensáveis.' `
        'Em Recursos opcionais, examine os itens instalados e remova somente aqueles cuja função você conhece e não usa, como um cliente opcional. Preserve os componentes dos quais depende.' 'ms-settings:optionalfeatures'

    New-OptimizerTweak discordoverlay 'Desligar sobreposição do Discord' Debloat Manual `
        'Evita que a sobreposição participe da sessão gráfica do jogo e ajuda a isolar conflitos.' `
        'No Discord, vá a Configurações do usuário → Sobreposição de jogo. Desative a sobreposição ou desligue apenas para o jogo nas configurações de jogos registrados.'

    New-OptimizerTweak backgroundbrowser 'Impedir navegador ativo após fechar' Debloat Manual `
        'Evita que extensões e aplicativos web continuem usando recursos depois de fechar a janela.' `
        'No Edge, abra Configurações → Sistema e desempenho. Desative a opção de continuar executando extensões e aplicativos em segundo plano quando o Edge for fechado. No Chrome, procure a opção equivalente em Sistema.'

    New-OptimizerTweak startupboost 'Desativar inicialização rápida do Edge' Debloat Manual `
        'Impede o pré-carregamento de processos do Edge depois que você entra na conta, com possível abertura mais lenta do navegador.' `
        'No Edge, abra Configurações → Sistema e desempenho → Sistema. Desative Impulso de inicialização, se estiver disponível. Teste o uso de memória após iniciar o Windows.'

    New-OptimizerTweak taskmanager 'Fechar tarefas pesadas antes de jogar' Debloat Manual `
        'Ajuda a reduzir paginação e a disputa por CPU, GPU, disco ou memória.' `
        'Pressione Ctrl+Shift+Esc e ordene Processos por Memória, CPU ou Disco. Salve o trabalho e feche pelo menu normal os aplicativos pessoais dispensáveis, como editores e janelas de vídeo.'

    New-OptimizerTweak storagesense 'Configurar Sensor de Armazenamento' Hardware Windows `
        'Remove temporários de forma programada na unidade do Windows e ajuda a preservar espaço para atualizações.' `
        'Abra Sensor de Armazenamento e revise cada regra. Deixe Downloads em Nunca para preservar seus arquivos e escolha conscientemente a política da Lixeira antes de ativar.' 'ms-settings:storagepolicies'

    New-OptimizerTweak optimizestorage 'Otimizar a unidade pelo Windows' Hardware Manual `
        'Usa a manutenção apropriada ao tipo de disco, como TRIM para SSDs e desfragmentação para HDs.' `
        'Busque Desfragmentar e Otimizar Unidades no menu Iniciar. Selecione a unidade correta e verifique se existe um agendamento ativo. Se precisar executar manualmente, faça fora do horário de jogo.'

    New-OptimizerTweak fortnitessd 'Mover um jogo para um SSD existente' Hardware Link `
        'Pode reduzir esperas de carregamento se o jogo estiver instalado em HD e houver espaço em um SSD.' `
        'Confira no scanner se há um SSD com espaço. Para jogos da Epic, abra o guia. Na Steam, procure a opção Mover em Configurações → Armazenamento. Confirme a unidade antes de mover.' 'https://www.epicgames.com/help/c-32735058/c-36403860/a12469649?lang=pt-BR'

    New-OptimizerTweak chipset 'Conferir o driver do chipset' Hardware Manual `
        'Uma versão compatível pode corrigir problemas de energia, estabilidade ou comunicação com dispositivos.' `
        'Veja o modelo da placa-mãe no scanner. Consulte a página oficial de suporte da placa ou do PC e busque o pacote do chipset para a sua versão do Windows. Confira as notas antes da instalação.'

    New-OptimizerTweak ramchannels 'Conferir canais da memória' Hardware Manual `
        'Módulos compatíveis nos encaixes corretos podem aumentar a largura de banda em placas com múltiplos canais.' `
        'Confira os módulos que o scanner detectou. Se você já usa dois pentes, confirme os encaixes recomendados no manual da placa-mãe. Desligue o PC da tomada antes de mover qualquer módulo.'

    New-OptimizerTweak pagefile 'Usar paginação gerenciada pelo Windows' Hardware Manual `
        'Ajuda a evitar erros por falta de memória quando jogo, voz e navegador dividem a RAM.' `
        'Em Win+R, execute SystemPropertiesAdvanced.exe. Abra Desempenho → Configurações → Avançado → Memória virtual → Alterar. Marque Gerenciar automaticamente e reinicie se solicitado.'

    New-OptimizerTweak cooling 'Reduzir limitação térmica' Hardware Manual `
        'Melhora a sustentação de clocks caso CPU ou GPU estejam reduzindo a frequência por aquecimento.' `
        'Desobstrua as entradas e saídas de ar. Com o PC desligado da tomada, inspecione filtros e poeira conforme o manual do gabinete. Compare temperatura, clocks e fluidez na mesma carga antes e depois.'

    New-OptimizerTweak perfmode 'Modo Desempenho' Fortnite Manual `
        'Reduz a complexidade visual para aliviar a hardware e favorecer FPS.' `
        'No Fortnite, abra Configurações → Vídeo → Modo de renderização → Desempenho. Aplique e reinicie o jogo. Use como ponto de partida para jogar competitivo.'

    New-OptimizerTweak reflex 'Ativar NVIDIA Reflex' Fortnite Manual `
        'Reduz a fila de renderização em situações compatíveis e pode diminuir o atraso entre o comando e a imagem.' `
        'Em uma GeForce compatível, abra Configurações → Vídeo → NVIDIA Reflex de baixa latência e selecione Ligado. Se Ligado + Boost aparecer, compare separadamente. O Boost pode elevar consumo e temperatura.'

    New-OptimizerTweak framecap 'Limitar FPS a um valor sustentável' Fortnite Manual `
        'Um teto de FPS sustentável pode reduzir oscilações de fluidez e evitar saturação constante da GPU.' `
        'Em Vídeo → Limite da taxa de quadros, comece próximo da frequência da tela. Com V-Sync desligado, compare uma taxa maior se o PC a sustentar em partida. O jogo pode responder mais rápido, com possibilidade de cortes na imagem.'

    New-OptimizerTweak vsync 'Testar V-Sync desligado' Fortnite Manual `
        'Pode reduzir o atraso associado à sincronização vertical. A imagem pode apresentar cortes horizontais.' `
        'Em Configurações → Vídeo, defina V-Sync como Desligado e compare. Se o monitor oferece G-SYNC ou VRR e você prioriza imagem sem cortes, avalie a configuração compatível com esse recurso.'

    New-OptimizerTweak fullscreen 'Comparar tela cheia e sem bordas' Fortnite Manual `
        'A forma de apresentação dos quadros pode afetar fluidez, latência e uso de sobreposições.' `
        'Em Vídeo → Modo de janela, compare Tela cheia e Tela cheia em janela. Use a mesma cena e o mesmo limite de FPS. No Windows 11, o resultado depende do modo de renderização e do caminho de apresentação.'

    New-OptimizerTweak native1080 'Testar 1920 × 1080 se a GPU limitar' Fortnite Manual `
        'Em telas de resolução maior, jogar em 1080p reduz a quantidade de pixels renderizados pela GPU.' `
        'Em Vídeo → Resolução, comece pela resolução nativa do monitor. Se a GPU limitar o FPS e a tela oferecer 1080p, compare a nitidez e a fluidez nesse modo.'

    New-OptimizerTweak renderres 'Ajustar resolução 3D' Fortnite Manual `
        'Reduzir a escala interna alivia a GPU quando ela é o gargalo, com perda de nitidez.' `
        'Comece em 100%. Se a GPU permanecer perto de 100% e o FPS estiver abaixo da meta, use Vídeo → Resolução 3D e teste 90%, depois 85%, quando disponível. Mantenha o valor mais nítido que couber na meta.'

    New-OptimizerTweak shadows 'Desligar sombras' Fortnite Manual `
        'Diminui o custo de renderização e deixa áreas escuras visualmente mais definidas.' `
        'Em Configurações → Vídeo → Qualidade de vídeo, selecione Sombras → Desligado quando o modo de renderização expuser a opção.'

    New-OptimizerTweak textures 'Usar texturas baixas' Fortnite Manual `
        'Reduz o uso de VRAM em áreas e partidas mais carregadas.' `
        'Em Vídeo → Texturas, teste Baixa. Passe para Média somente se a nitidez extra compensar e as travadas ou o uso de VRAM não aumentarem na mesma cena.'

    New-OptimizerTweak effects 'Reduzir a qualidade dos efeitos' Fortnite Manual `
        'Reduz o custo de partículas e efeitos de combate quando o modo gráfico oferece esse controle.' `
        'Abra Vídeo → Efeitos e selecione Baixo. Compare em cenas com explosões, construções e vários jogadores.'

    New-OptimizerTweak postprocess 'Reduzir o pós-processamento' Fortnite Manual `
        'Reduz o trabalho feito após a renderização e pode ajudar quando a GPU limita o FPS.' `
        'Em Configurações → Vídeo, procure Pós-processamento e selecione Baixo, se visível. Aplique e compare com o valor anterior.'

    New-OptimizerTweak viewdistance 'Ajustar a distância de visão' Fortnite Manual `
        'Reduzir a distância de detalhes pode aliviar CPU e GPU, com impacto na apresentação do cenário.' `
        'Em Vídeo → Distância de visão, comece em Média. Se a fluidez cair em áreas densas, teste Perto. Confira como cada valor afeta a leitura do cenário à distância.'

    New-OptimizerTweak nanite 'Desativar geometria Nanite' Fortnite Manual `
        'Poupa trabalho da GPU em DX12 ao usar a geometria convencional, com redução de detalhe.' `
        'Em DX12, abra Vídeo → Geometria virtualizada Nanite e desligue, se aparecer. Em Modo Desempenho, ignore esta opção quando ela não estiver disponível.'

    New-OptimizerTweak lumen 'Reduzir iluminação global e reflexos' Fortnite Manual `
        'A iluminação e os reflexos avançados podem elevar o uso da GPU em DX12.' `
        'Em DX12, abra Vídeo e selecione a opção mais leve para Iluminação global e Reflexos. Se as opções estiverem ocultas no modo atual, siga com o preset de desempenho.'

    New-OptimizerTweak tsr 'Testar super-resolução temporal' Fortnite Manual `
        'Renderiza internamente com menos pixels para aliviar a GPU, com possíveis artefatos em movimento.' `
        'Em DX12, abra Vídeo → Anti-aliasing e super-resolução. Se TSR estiver disponível, compare Qualidade e Equilibrado na mesma cena.'

    New-OptimizerTweak meshes 'Usar malhas baixas' Fortnite Manual `
        'Simplifica a geometria exibida quando o Modo Desempenho oferece esse controle.' `
        'Em Vídeo → Malhas, selecione Baixa, se a opção estiver disponível. Compare a leitura de construções e objetos antes de manter o ajuste.'

    New-OptimizerTweak hdpak 'Remover texturas de alta resolução' Fortnite Manual `
        'Libera espaço de instalação quando você prefere jogar com texturas leves.' `
        'Feche o Fortnite. No inicializador da Epic, vá a Biblioteca → Fortnite → três pontos → Opções. Desmarque Texturas de alta resolução e aplique. Reinstale o pacote pelo mesmo menu caso queira voltar.'

    New-OptimizerTweak replays 'Desativar replays automáticos' Fortnite Manual `
        'Evita gravações de partidas em segundo plano e reduz escritas de arquivos durante o jogo.' `
        'Em Configurações → Jogo → Replays, desative as opções de gravação que você não usa. Você deixará de ter replays das novas partidas nesses modos.'

    New-OptimizerTweak dx12 'Comparar Modo Desempenho e DX12' Fortnite Manual `
        'Compara a regularidade dos quadros entre os caminhos de renderização disponíveis no Fortnite.' `
        'Registre o resultado no Modo Desempenho. Depois, em Vídeo → Modo de renderização, selecione DirectX 12 e reinicie. Use o preset Baixo e espere algumas rodadas para aquecer o cache antes de medir novamente.'

    New-OptimizerTweak verifyfortnite 'Verificar arquivos do Fortnite' Fortnite Manual `
        'Repara arquivos da instalação quando há suspeita de falha após atualização ou travamentos recorrentes.' `
        'Feche o jogo. Na Biblioteca da Epic, escolha Fortnite → três pontos → Gerenciar → Verificar. Aguarde a verificação e reinicie o jogo.'

    New-OptimizerTweak showfps 'Mostrar FPS durante a partida' Fortnite Manual `
        'Permite detectar quedas e comparar alterações nas mesmas condições.' `
        'Em Configurações → Vídeo, ligue Exibir FPS. Compare com o mesmo modo, mapa e limite. Mudanças de cena e partidas diferentes podem distorcer a comparação.'

    New-OptimizerTweak matchmaking 'Ajustar a região de pareamento' Fortnite Manual `
        'Ajuda a conectar ao servidor com melhor latência sem alterar o adaptador ou o Registro.' `
        'Em Configurações → Jogo → Idioma e região, comece em Automático. Se sua rota estiver ruim, compare com a região mais próxima que mostrar menor ping e confirme em uma partida.'

    New-OptimizerTweak netstats 'Exibir ping e perda de pacotes' Fortnite Manual `
        'Mostra problemas de conexão durante a partida e ajuda a separar rede instável de quedas de FPS.' `
        'No Fortnite, abra Configurações → Interface do Jogo e ligue as estatísticas de depuração de rede. Verifique ping e perda durante a partida, especialmente quando houver teleporte ou atraso.'

    New-OptimizerTweak shaderrepair 'Reparar cache de shaders sob sintomas' Fortnite Link `
        'Pode resolver travadas persistentes ligadas à recompilação de shaders em DX12. As primeiras partidas podem compilar novamente.' `
        'Use apenas se houver engasgos persistentes em DX12 compatíveis com o problema descrito pela Epic. Feche Fortnite e Epic Games Launcher e siga os passos oficiais para NVIDIA.' 'https://www.epicgames.com/help/c-34254770/c-38015632/a11302262?lang=pt-BR'
)

$automaticInstructions = @{
    gamefpscap = 'Use o GameUserSettings.ini de um jogo Unreal compatível e escolha o limite em FPS. Com o jogo fechado, o PrismaFrame atualiza o limite registrado. Compare os tempos de quadro na mesma cena.'
    gamedynamicres = 'Selecione o GameUserSettings.ini de um jogo Unreal compatível. O PrismaFrame liga a resolução dinâmica quando o arquivo expõe a opção. O suporte e a qualidade dependem do jogo.'
    gamevsync = 'Teste V-Sync desligado em um jogo Unreal compatível. Selecione o GameUserSettings.ini com o jogo fechado. A imagem pode apresentar cortes horizontais.'
    gamewindowmode = 'Selecione o GameUserSettings.ini de um jogo Unreal compatível. O PrismaFrame seleciona tela cheia, se o arquivo expuser a opção. Compare com seu modo anterior.'
    gamebackgroundfps = 'Em PCs NVIDIA, selecione o executável do jogo e um limite entre 20 e 200 FPS para quando ficar em segundo plano. A aplicação depende do suporte do driver e do jogo.'
    winanimations = 'Ajusta os efeitos SPI de animação da interface do Windows. Pode simplificar transições na área de trabalho. O efeito durante o jogo depende da carga do sistema.'
    gamegpu = 'Escolha o executável principal do jogo. O PrismaFrame grava a preferência Alto desempenho do Windows para esse executável. Reabra o jogo e confirme a GPU selecionada.'
    hags = 'Testa a ativação de HAGS quando o driver indica suporte. Requer administrador e reinicialização. Compare a estabilidade antes de manter a configuração.'
    flipmodel = 'Ativa a preferência global de otimizações para jogos em janela no Windows 11 22H2 ou mais recente. Jogos DirectX 10/11 compatíveis podem usar um modo de apresentação de menor latência.'
    nvpstate = 'Selecione o executável do jogo para testar o modo NVIDIA Preferir desempenho máximo. Pode aumentar consumo e temperatura durante o jogo.'
    nvtexture = 'Selecione o executável para ajustar a filtragem de textura NVIDIA para Desempenho. Compare nitidez e FPS, especialmente se o jogo já limitar pela GPU.'
    shadercache = 'Ativa o cache de shaders global do driver NVIDIA. O cache pode reduzir recompilações em partidas futuras e ocupa espaço em disco.'
    nvlowlatency = 'Selecione o executável para limitar a fila compatível do driver NVIDIA a um quadro pré-renderizado. Use em jogos sem Reflex. O efeito depende da API e do controle da fila pelo jogo.'
    stickykeys = 'Desativa apenas o atalho de cinco pressões da tecla Shift para Teclas de Aderência. O estado do recurso de acessibilidade é preservado.'
    filterkeys = 'Desativa apenas o atalho de segurar Shift direito para Teclas de Filtro. O estado do recurso de acessibilidade é preservado.'
    deliveryoptimization = 'Configura a Otimização de Entrega do Windows para baixar via HTTP sem compartilhamento entre PCs. Requer administrador. O Windows continua baixando atualizações.'
    backgroundapps = 'Aplica a política do Windows que restringe apps empacotados em segundo plano. Pode interromper notificações desses apps. Requer administrador.'
    backgroundbrowser = 'Desativa a execução do Microsoft Edge em segundo plano depois de fechar a última janela. Reabra o Edge para que ele leia a política.'
    startupboost = 'Desativa a Inicialização Rápida do Microsoft Edge. A primeira abertura poderá demorar mais. Reabra o Edge para que ele leia a política.'
    framecap = 'Feche o Fortnite e escolha um limite de 30 a 360 FPS. Comece com um limite sustentável. Compare o resultado com V-Sync, frequência da tela e tempos de quadro.'
    vsync = 'Com o Fortnite fechado, desativa V-Sync quando o arquivo do jogo expõe a configuração. A imagem pode apresentar cortes horizontais.'
    fullscreen = 'Com o Fortnite fechado, seleciona tela cheia quando o arquivo expõe o modo de janela. Compare com o modo anterior.'
    renderres = 'Com o Fortnite fechado, testa escala interna de 90% quando o modo expõe a opção. Reduz trabalho da GPU em troca de nitidez.'
    shadows = 'Com o Fortnite fechado, define Sombras no nível baixo quando o arquivo expõe essa opção.'
    textures = 'Com o Fortnite fechado, testa Texturas no nível baixo quando o arquivo expõe essa opção.'
    effects = 'Com o Fortnite fechado, define Efeitos no nível baixo quando o arquivo expõe essa opção.'
    postprocess = 'Com o Fortnite fechado, define Pós-processamento no nível baixo quando o arquivo expõe essa opção.'
    viewdistance = 'Com o Fortnite fechado, define Distância de visão no nível baixo quando o arquivo expõe essa opção. Compare a visibilidade.'
    nanite = 'Com o Fortnite fechado, desativa Nanite quando o arquivo expõe essa opção. O efeito depende do modo de renderização.'
    lumen = 'Com o Fortnite fechado, reduz os níveis existentes de iluminação global e reflexos. O efeito depende do modo de renderização.'
    showfps = 'Com o Fortnite fechado, ativa o contador de FPS quando o arquivo expõe a opção. Use a mesma cena ao comparar.'
}

foreach ($tweak in $script:Tweaks) {
    if ($automaticInstructions.ContainsKey($tweak.Id)) {
        $tweak.Mode = 'Auto'
        $tweak.Instructions = $automaticInstructions[$tweak.Id]
        $tweak.Target = ''
    }
}

($script:Tweaks | Where-Object Id -eq 'gamefpscap').Title = 'Definir limite de FPS em jogos Unreal'
($script:Tweaks | Where-Object Id -eq 'gamevsync').Title = 'Testar V-Sync desligado em jogos Unreal'
($script:Tweaks | Where-Object Id -eq 'gamevsync').Summary = 'Pode reduzir a espera pela sincronização da tela, com chance de cortes horizontais na imagem.'
($script:Tweaks | Where-Object Id -eq 'gamewindowmode').Title = 'Testar tela cheia em jogos Unreal'
($script:Tweaks | Where-Object Id -eq 'gamedynamicres').Title = 'Testar resolução dinâmica em jogos Unreal'

$script:Tweaks += @(
    New-OptimizerTweak gamefpscapguide 'Escolher um limite de FPS dentro do jogo' Jogos Manual `
        'Um teto que o PC sustenta ajuda a comparar estabilidade, ruído e resposta em qualquer motor.' `
        'Use o limitador nas opções de vídeo do jogo quando disponível. Comece perto da taxa da tela e compare com um limite sustentado usando o mesmo percurso.'
    New-OptimizerTweak uescale 'Testar escala de renderização a 90%' Jogos Auto `
        'Diminui o número de pixels internos quando o jogo está limitado pela GPU.' `
        'Selecione o GameUserSettings.ini de um jogo Unreal compatível. Se a opção estiver presente, o aplicativo testa 90%. Compare a nitidez.'
    New-OptimizerTweak ueview 'Reduzir distância de visão' Jogos Auto `
        'Pode reduzir a quantidade de objetos distantes que a CPU e a GPU precisam processar.' `
        'Selecione o GameUserSettings.ini de um jogo Unreal compatível. O grupo View Distance vai para Baixo se estiver presente.'
    New-OptimizerTweak ueaa 'Reduzir qualidade do antisserrilhado' Jogos Auto `
        'Reduz o custo potencial de suavizar bordas em troca de mais serrilhado.' `
        'Ajusta para Baixo o grupo de antisserrilhado no arquivo de um jogo Unreal compatível. Confira se o jogo respeitou o nível.'
    New-OptimizerTweak ueshadows 'Reduzir qualidade das sombras' Jogos Auto `
        'Diminui o custo de gerar sombras, com redução de detalhes visuais.' `
        'Ajusta para Baixo o grupo de sombras no GameUserSettings.ini de um jogo Unreal compatível.'
    New-OptimizerTweak ueglobalillumination 'Reduzir iluminação global' Jogos Auto `
        'Pode aliviar o cálculo de luz indireta em jogos que usam esse grupo do Unreal.' `
        'Ajusta a iluminação global para Baixo quando o jogo expõe o grupo. Compare a aparência em interiores.'
    New-OptimizerTweak uereflections 'Reduzir qualidade dos reflexos' Jogos Auto `
        'Pode reduzir o custo de renderizar reflexos em superfícies brilhantes.' `
        'Ajusta reflexos para Baixo quando o jogo expõe o grupo. Compare áreas com água ou metal.'
    New-OptimizerTweak uepostprocess 'Reduzir pós-processamento' Jogos Auto `
        'Diminui o custo de efeitos aplicados depois de renderizar a cena.' `
        'Ajusta pós-processamento para Baixo no GameUserSettings.ini de um jogo Unreal compatível.'
    New-OptimizerTweak uetextures 'Reduzir qualidade de texturas' Jogos Auto `
        'Pode reduzir pressão na VRAM. Texturas podem parecer menos nítidas.' `
        'Ajusta texturas para Baixo no GameUserSettings.ini de um jogo Unreal compatível. Compare travadas ao percorrer o mesmo cenário.'
    New-OptimizerTweak ueeffects 'Reduzir qualidade dos efeitos' Jogos Auto `
        'Pode aliviar partículas e efeitos visuais em cenas carregadas.' `
        'Ajusta efeitos para Baixo no GameUserSettings.ini de um jogo Unreal compatível.'
    New-OptimizerTweak uefoliage 'Reduzir vegetação' Jogos Auto `
        'Pode reduzir densidade e custo de vegetação em cenas abertas.' `
        'Ajusta vegetação para Baixo quando o jogo Unreal expõe o grupo. Confira o resultado em áreas abertas.'
    New-OptimizerTweak ueshading 'Reduzir qualidade de sombreamento' Jogos Auto `
        'Pode reduzir o custo de materiais e sombreamento da cena.' `
        'Ajusta para Baixo o grupo de sombreamento quando o jogo Unreal o expõe.'
    New-OptimizerTweak uelandscape 'Reduzir qualidade do terreno' Jogos Auto `
        'Pode simplificar a renderização do terreno em ambientes grandes.' `
        'Ajusta para Baixo o grupo de paisagem quando o jogo Unreal o expõe.'

    New-OptimizerTweak nvfpscap 'Limitar FPS pelo driver NVIDIA' GPU Auto `
        'Pode moderar consumo e saturação da GPU em jogos compatíveis.' `
        'Selecione o executável e um limite inteiro de 20 a 1000 FPS. Compare com o limite interno do jogo e evite empilhar limitadores durante a comparação.'
    New-OptimizerTweak nvvsyngeneric 'Testar V-Sync desligado no perfil NVIDIA' GPU Auto `
        'Pode retirar a espera por atualização de tela se o driver controlar a sincronização. Pode causar tearing.' `
        'Escolha o executável do jogo. Confira se a API e o jogo aceitam a substituição do driver.'
    New-OptimizerTweak nvpreferredrefresh 'Preferir frequência máxima no perfil NVIDIA' GPU Auto `
        'Pede ao driver a maior frequência compatível para o jogo escolhido quando o modo de tela permitir.' `
        'Escolha o executável e confirme no monitor em que você joga. A opção depende da tela e do modo de exibição.'
    New-OptimizerTweak nvogltriplebuffer 'Testar buffer triplo no OpenGL' GPU Auto `
        'Pode melhorar a fluidez em jogos OpenGL com V-Sync. Pode aumentar a latência.' `
        'Use em um executável NVIDIA OpenGL compatível com V-Sync. Compare o tempo de resposta e a estabilidade dos quadros.'
    New-OptimizerTweak nvoglthreaded 'Testar otimização multithread no OpenGL' GPU Auto `
        'Permite ao driver NVIDIA usar otimização por threads para jogos OpenGL compatíveis.' `
        'Selecione o executável. Compare com o comportamento automático, pois alguns jogos funcionam melhor na configuração anterior.'
    New-OptimizerTweak nvfxaaoff 'Desligar FXAA pelo driver NVIDIA' GPU Auto `
        'Evita que o driver aplique seu filtro de antisserrilhado ao jogo escolhido.' `
        'Selecione o executável e compare a nitidez e o custo. O antisserrilhado interno do jogo continua independente.'
    New-OptimizerTweak nvtrilinear 'Otimizar a filtragem trilinear NVIDIA' GPU Auto `
        'Pode aliviar filtragem de texturas com redução de qualidade em algumas superfícies.' `
        'Selecione o executável e compare em jogos DirectX que aceitem a opção. Observe texturas vistas de longe.'
    New-OptimizerTweak nvanisosample 'Otimizar amostras anisotrópicas NVIDIA' GPU Auto `
        'Reduz amostras de filtragem em jogos compatíveis, com possível perda de nitidez em ângulo.' `
        'Selecione o executável e compare superfícies inclinadas no mesmo trajeto.'
    New-OptimizerTweak nvshadercachesize 'Reservar até 10 GB para cache NVIDIA' GPU Auto `
        'Pode reduzir a expulsão de shaders compilados em bibliotecas com vários jogos.' `
        'Ajuste global do driver. O aplicativo verifica se há pelo menos 15 GB livres na unidade do perfil antes de aplicar o limite.'

    New-OptimizerTweak winwindragoutline 'Mostrar contorno ao mover janelas' Windows Auto `
        'Reduz a atualização de conteúdo quando você arrasta uma janela.' `
        'Troca o redesenho durante o arraste pela exibição de contorno. O efeito é restrito à área de trabalho.'
    New-OptimizerTweak poweracminimum 'Manter piso de CPU em 25% na tomada' Windows Auto `
        'Evita um nível mínimo muito baixo em planos compatíveis, com possível aumento de consumo.' `
        'Pode elevar o mínimo a até 25%, respeitando o máximo atual e preservando mínimos já maiores. A alteração vale na tomada.'
    New-OptimizerTweak poweracmaximum 'Permitir CPU em 100% na tomada' Windows Auto `
        'Remove um teto abaixo de 100% no plano ativo, se a opção estiver disponível.' `
        'Ajusta apenas o uso na tomada. Respeita limites do processador, refrigeração e firmware.'
    New-OptimizerTweak poweracboost 'Habilitar o modo de boost da CPU na tomada' Windows Auto `
        'Permite aceleração acima da frequência nominal em CPUs compatíveis.' `
        'Habilita o boost no plano ativo quando disponível e preserva os modos já ativos. Compare consumo e estabilidade térmica.'
    New-OptimizerTweak poweracepp 'Dar mais preferência ao desempenho em EPP' Windows Auto `
        'Ajusta a preferência energética para 30 de 100 na tomada quando o hardware a usa e o plano ainda favorece mais a economia.' `
        'Preserva preferências que já favorecem mais o desempenho. O teste pode aumentar temperatura e ruído.'
    New-OptimizerTweak poweracparking 'Testar o plano sem estacionamento de núcleos' Windows Auto `
        'Mantém todos os núcleos elegíveis no plano de energia quando ligado à tomada.' `
        'Teste em jogos sensíveis às transições do plano. Pode elevar consumo em repouso e o ganho depende da CPU.'
    New-OptimizerTweak poweracpcie 'Desligar economia do link PCIe na tomada' Windows Auto `
        'Evita transições de economia do link em dispositivos que respeitam a política.' `
        'Aplica somente no plano ativo e na tomada. Compare estabilidade e consumo.'
    New-OptimizerTweak poweracdiskidle 'Evitar desligamento de HDD por inatividade' Hardware Auto `
        'Pode evitar a espera para o disco voltar a girar quando o jogo volta a usar um HDD.' `
        'Define o tempo de desligamento por ociosidade como Nunca na tomada. Use se os jogos usam um HDD. O disco pode gastar mais energia.'
    New-OptimizerTweak keyboarddelay 'Usar o menor atraso de repetição do teclado' Entrada Auto `
        'Reduz a espera até o início da repetição de uma tecla mantida no Windows.' `
        'Ajusta a repetição do teclado para o menor atraso. A primeira pressão e jogos que usam entrada bruta ficam independentes.'
    New-OptimizerTweak keyboardrepeat 'Usar a maior velocidade de repetição do teclado' Entrada Auto `
        'Aumenta a frequência de repetição de uma tecla mantida nas interfaces que usam o valor do Windows.' `
        'Teste em jogos e menus que usam repetição da área de trabalho. Pode dificultar digitação em outros aplicativos.'
    New-OptimizerTweak mousecursortrail 'Desligar rastros do ponteiro' Entrada Auto `
        'Remove as cópias visuais que seguem o ponteiro pelo Windows.' `
        'Aplica ao ponteiro da área de trabalho e a jogos que o usam. Se você depende dos rastros para enxergar o cursor, mantenha a configuração anterior.'
    New-OptimizerTweak mousesnapdefault 'Impedir saltos do ponteiro para botões' Entrada Auto `
        'Evita mover o ponteiro automaticamente para o botão padrão de caixas de diálogo.' `
        'Aplica à sessão do Windows e às interfaces que usam o comportamento de botão padrão.'
    New-OptimizerTweak mousepointerdefault 'Restaurar velocidade padrão do ponteiro' Entrada Auto `
        'Define o controle de velocidade do Windows em 10 de 20 como referência consistente.' `
        'Confira sua sensibilidade antes de aplicar. Jogos que usam entrada bruta podem ter controle independente.'
    New-OptimizerTweak togglekeyshotkey 'Desativar o atalho de Teclas de Alternância' Entrada Auto `
        'Evita que segurar Num Lock alterne avisos sonoros sem querer.' `
        'Muda apenas o atalho. O recurso de acessibilidade continua no estado atual.'
    New-OptimizerTweak mousekeyshotkey 'Desativar o atalho de Teclas do Mouse' Entrada Auto `
        'Evita que a combinação acidental ative o controle do ponteiro pelo teclado.' `
        'Muda apenas o atalho. O recurso de acessibilidade continua no estado atual.'
    New-OptimizerTweak chromebackground 'Desativar execução do Chrome após fechar' Debloat Auto `
        'Pode reduzir uso de memória e CPU de extensões quando nenhuma janela do Chrome está aberta.' `
        'Aplica a política de execução em segundo plano ao Chrome. Algumas extensões deixam de funcionar após fechar a última janela.'
    New-OptimizerTweak deliverybackgroundlimit 'Limitar downloads de entrega em segundo plano' Rede Auto `
        'Restringe downloads em segundo plano da Otimização de Entrega a 10% da banda medida.' `
        'Requer administrador. Pode alongar downloads de atualizações distribuídos pela Otimização de Entrega.'
    New-OptimizerTweak deliveryforegroundlimit 'Limitar downloads de entrega em primeiro plano' Rede Auto `
        'Restringe downloads de primeiro plano da Otimização de Entrega a 25% da banda medida.' `
        'Requer administrador. Pode alongar downloads de atualização iniciados por você.'
)

$script:Sources += @(
    [pscustomobject]@{ Label = 'Unreal Engine · Game User Settings'; Url = 'https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UGameUserSettings' }
    [pscustomobject]@{ Label = 'Unreal Engine · Níveis de escalabilidade'; Url = 'https://dev.epicgames.com/documentation/en-us/unreal-engine/scalability-reference-for-unreal-engine' }
    [pscustomobject]@{ Label = 'NVIDIA · Perfis de driver'; Url = 'https://docs.nvidia.com/nvapi/group__drsapi.html' }
    [pscustomobject]@{ Label = 'NVIDIA · Referência de opções 3D'; Url = 'https://www.nvidia.com/content/Control-Panel-Help/vLatest/en-us/mergedProjects/nv3d/Manage_3D_Settings_%28reference%29.htm' }
    [pscustomobject]@{ Label = 'Microsoft · Opções de energia'; Url = 'https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options' }
    [pscustomobject]@{ Label = 'Microsoft · Preferências de interface e entrada'; Url = 'https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow' }
    [pscustomobject]@{ Label = 'Microsoft · Otimização de Entrega'; Url = 'https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference' }
    [pscustomobject]@{ Label = 'Microsoft Edge · Execução em segundo plano'; Url = 'https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/backgroundmodeenabled' }
    [pscustomobject]@{ Label = 'Google Chrome · Política de execução em segundo plano'; Url = 'https://chromeenterprise.google/intl/en_us/policies/#BackgroundModeEnabled' }
)
