# PrismaFrame

Otimizador gratuito em português para ajustar FPS, estabilidade e latência em jogos de PC. A maior parte da biblioteca é aplicável pelo aplicativo e o Fortnite tem uma seção opcional. O scanner identifica o hardware do PC e gera um perfil de recomendações locais.

## Abrir o aplicativo

1. Baixe **PrismaFrame-Setup.msi** na versão mais recente no GitHub, execute o instalador e abra **PrismaFrame** no menu Iniciar. Para usar a versão portátil, baixe e abra **PrismaFrame.exe**.
2. Em **Scanner do PC**, consulte **Perfil para jogos** e **Especificações**. Use **Escanear novamente** para atualizar a leitura e **Copiar relatório** para guardar as informações.
3. Abra **Ajustes** e escolha **Automáticos** para ver o que o app consegue aplicar. Em **Revisar pacote básico**, selecione os ajustes do Windows que quer aplicar juntos.

O instalador padrão adiciona o PrismaFrame à conta atual. Para remover, procure **PrismaFrame** em **Configurações → Aplicativos**. Os backups de ajustes podem ser acessados novamente se você reinstalar o aplicativo. A versão instalada e a portátil usam o Windows PowerShell 5.1 e o WPF do Windows 10 e 11 x64.

## Ajustes para jogos

- **Automático** aplica uma configuração mediante confirmação. Há ajustes de Windows e energia, perfis NVIDIA e configurações locais para jogos compatíveis com Unreal. Cada mudança guarda os valores anteriores no histórico.
- **Configurações do Windows** abre a área correspondente para fazer a alteração. O catálogo de debloat cobre aplicativos, inicialização e atividades em segundo plano.
- **Guia manual** e **Guia com link oficial** indicam onde configurar o jogo, a GPU, os periféricos, o monitor, a rede ou o hardware. A seção Fortnite cobre renderização, NVIDIA Reflex, limite de quadros e região de partidas, entre outros ajustes.

Os ajustes **NVIDIA** pedem o executável principal do jogo quando afetam um perfil individual. Os ajustes **Unreal** pedem o `GameUserSettings.ini` local, normalmente em `%LOCALAPPDATA%\<NomeDoJogo>\Saved\Config\Windows` ou em `Documentos\My Games`. Feche o jogo antes de editar esse arquivo. O aplicativo aplica somente chaves reconhecidas já presentes. A compatibilidade depende do jogo, da API gráfica, do driver ou da edição do Windows.

O relatório inclui processador, GPU e VRAM, módulos de RAM, armazenamento, placa-mãe, BIOS, telas, rede e versão do Windows, conforme os dados disponibilizados pelo sistema e pelos drivers. O perfil cruza dados como frequência e resolução da tela, GPU, VRAM, RAM e tipo de unidade com as opções da biblioteca. Em PCs com mais de uma GPU, o perfil orienta a verificar qual placa o jogo usa. As sugestões são calculadas localmente e cada alteração automática exige confirmação.

Para comparar desempenho, teste um ajuste por vez e repita a mesma cena ou percurso no mesmo jogo e com a mesma resolução. Compare a estabilidade dos quadros e, quando o jogo oferecer a medição, a latência. Os resultados variam com o jogo, o driver, o monitor e a carga do PC.

## Limpeza

Em **Limpeza**, selecione as categorias e clique em **Analisar arquivos**. A prévia mostra a quantidade e o tamanho estimado dos arquivos por categoria. Clique em **Revisar e excluir** e confirme em **Excluir arquivos** para fazer a exclusão permanente. O aplicativo ignora arquivos que mudaram após a prévia ou que estão em uso.

A seleção inicial cobre arquivos `.tmp` e `.temp` antigos do usuário. Temporários do Windows, relatórios de falhas e registros antigos do Fortnite e do Epic Games Launcher estão em categorias opcionais. A limpeza recupera espaço em disco e o tamanho exibido corresponde à soma dos tamanhos lógicos dos arquivos.

## Recuperação

- Para desfazer um ajuste automático, abra **Recuperação** e clique em **Desfazer** no item correspondente. Os backups ficam em `%LOCALAPPDATA%\Pulso Arena\Backups` para continuar acessíveis após a mudança de nome.
- Para criar um ponto do Windows, use **Reabrir como administrador** em **Recuperação**. Em **Abrir Proteção do Sistema**, confirme que a proteção da unidade do Windows está ativa. Depois, clique em **Criar ponto** e aguarde a confirmação do Windows. O Windows normalmente limita a criação automatizada a um ponto por período de 24 horas.
- Para aplicar um ponto, abra **Restauração do Sistema** nessa mesma tela e siga o assistente do Windows. O ponto cobre configurações e arquivos do sistema. A exclusão feita pela limpeza é permanente.

[Documentação da Microsoft sobre Proteção do Sistema](https://support.microsoft.com/en-us/windows/experience/backup-recovery/system-protection)

## Código-fonte

Para abrir uma cópia extraída do código-fonte, mantenha todos os arquivos na mesma pasta e execute **Abrir PrismaFrame.cmd**. Para compilar o executável no Windows x64, rode o script de compilação em uma sessão do Windows PowerShell 5.1 e indique o caminho de saída absoluto.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-PrismaFrameExe.ps1 -OutputPath (Join-Path $PWD 'PrismaFrame.exe')
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-PrismaFrameInstaller.ps1 -ExecutablePath (Join-Path $PWD 'PrismaFrame.exe') -Version 1.3.0 -OutputPath (Join-Path $PWD 'PrismaFrame-Setup.msi')
```

- `PrismaFrameHost.cs`, `PrismaFrame.manifest` e `Build-PrismaFrameExe.ps1` montam o executável com os recursos incorporados.
- `Build-PrismaFrameInstaller.ps1` empacota o executável em um MSI com atalho no menu Iniciar.
- `PrismaFrame.ps1` e `PrismaFrame.xaml` contêm a interface e conectam os recursos.
- `Tweaks.ps1` contém o catálogo, as descrições e as referências oficiais.
- `Scanner.ps1` reúne e apresenta os dados de hardware e do Windows.
- `Recommendations.ps1` gera o perfil de jogos com os dados estruturados do scanner.
- `Tuning.ps1` coordena os ajustes automáticos e mantém os backups necessários para desfazê-los.
- `WindowsTuning.ps1`, `NvidiaTuning.ps1` e `GameConfigTuning.ps1` cuidam dos ajustes da plataforma, do driver e dos arquivos locais de jogos compatíveis.
- `Maintenance.ps1` implementa a prévia, a limpeza e a integração com a Restauração do Sistema.
