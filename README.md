# Pulso Arena

Otimizador gratuito em português para ajustar FPS, estabilidade e latência em jogos de PC. O catálogo tem 100 opções, incluindo 12 ajustes automáticos e uma seção opcional para Fortnite. O aplicativo escaneia o PC em que abre e recomenda ajustes com base no hardware detectado.

## Abrir o aplicativo

1. Extraia toda a pasta do ZIP. Mantenha o iniciador e os arquivos `.ps1` e `.xaml` juntos.
2. Dê dois cliques em **Abrir Pulso Arena.cmd**.
3. Em **Scanner do PC**, consulte **Perfil para jogos** e **Especificações**. Use **Escanear novamente** para atualizar a leitura e **Copiar relatório** para guardar as informações.
4. Abra **Ajustes**, pesquise um termo ou escolha uma categoria. Cada opção explica o efeito esperado, como usá-la e as condições relevantes.

O aplicativo usa o Windows PowerShell 5.1 de 64 bits e o WPF que acompanham o Windows 10 e 11 de 64 bits. A opção de política de execução do iniciador vale apenas para a instância do PowerShell que carrega o aplicativo.

## Ajustes para jogos

- **Automático** aplica uma configuração pelo aplicativo mediante confirmação. As 12 opções automáticas abrangem o Registro do usuário e planos de energia. Cada alteração guarda a configuração anterior no histórico.
- **Configurações do Windows** abre a área correspondente para fazer a alteração. O catálogo de debloat cobre aplicativos, inicialização e atividades em segundo plano.
- **Guia manual** e **Guia com link oficial** indicam onde configurar o jogo, a GPU, os periféricos, o monitor, a rede ou o hardware. A seção Fortnite cobre renderização, NVIDIA Reflex, limite de quadros e região de partidas, entre outros ajustes.

O relatório inclui processador, GPU e VRAM, módulos de RAM, armazenamento, placa-mãe, BIOS, telas, rede e versão do Windows, conforme os dados disponibilizados pelo sistema e pelos drivers. O perfil cruza dados como frequência e resolução da tela, GPU, VRAM, RAM e tipo de unidade com as opções da biblioteca. Em PCs com mais de uma GPU, o perfil orienta a verificar qual placa o jogo usa. As sugestões são calculadas localmente e cada alteração automática exige confirmação.

Para comparar desempenho, teste um ajuste por vez e repita a mesma cena ou percurso no mesmo jogo e com a mesma resolução. Compare a estabilidade dos quadros e, quando o jogo oferecer a medição, a latência. Os resultados variam com o jogo, o driver, o monitor e a carga do PC.

## Limpeza

Em **Limpeza**, selecione as categorias e clique em **Analisar arquivos**. A prévia mostra a quantidade e o tamanho estimado dos arquivos por categoria. Clique em **Revisar e excluir** e confirme em **Excluir arquivos** para fazer a exclusão permanente. O aplicativo ignora arquivos que mudaram após a prévia ou que estão em uso.

A seleção inicial cobre arquivos `.tmp` e `.temp` antigos do usuário. Temporários do Windows, relatórios de falhas e registros antigos do Fortnite e do Epic Games Launcher estão em categorias opcionais. A limpeza recupera espaço em disco e o tamanho exibido corresponde à soma dos tamanhos lógicos dos arquivos.

## Recuperação

- Para desfazer um ajuste automático, abra **Recuperação** e clique em **Desfazer** no item correspondente. Os backups ficam em `%LOCALAPPDATA%\Pulso Arena\Backups`.
- Para criar um ponto do Windows, use **Reabrir como administrador** em **Recuperação**. Em **Abrir Proteção do Sistema**, confirme que a proteção da unidade do Windows está ativa. Depois, clique em **Criar ponto** e aguarde a confirmação do Windows. O Windows normalmente limita a criação automatizada a um ponto por período de 24 horas.
- Para aplicar um ponto, abra **Restauração do Sistema** nessa mesma tela e siga o assistente do Windows. O ponto cobre configurações e arquivos do sistema. A exclusão feita pela limpeza é permanente.

[Documentação da Microsoft sobre Proteção do Sistema](https://support.microsoft.com/en-us/windows/experience/backup-recovery/system-protection)

## Código-fonte

- `PulsoArena.ps1` e `PulsoArena.xaml` contêm a interface e conectam os recursos.
- `Tweaks.ps1` contém o catálogo, as descrições e as referências oficiais.
- `Scanner.ps1` reúne e apresenta os dados de hardware e do Windows.
- `Recommendations.ps1` gera o perfil de jogos com os dados estruturados do scanner.
- `Tuning.ps1` aplica os ajustes automáticos e mantém os backups necessários para desfazê-los.
- `Maintenance.ps1` implementa a prévia, a limpeza e a integração com a Restauração do Sistema.
