function New-GameRecommendation([string]$Id, [string]$Title, [string]$Reason) {
    [pscustomobject]@{ Id = $Id; Title = $Title; Reason = $Reason }
}

function Get-GameRecommendations($Profile) {
    if (-not $Profile) { return }
    $number = [Globalization.CultureInfo]::GetCultureInfo('pt-BR')

    if ($Profile.PrimaryHz) {
        $rate = $Profile.PrimaryHz
        $reason = "A tela principal está a $rate Hz. Use um limite que o jogo sustente na cena mais pesada. Comece medindo com um valor próximo à taxa da tela e compare limites maiores se quiser priorizar resposta."
        $action = if ($Profile.GPUVendor -eq 'NVIDIA' -and $Profile.GpuCount -eq 1) { 'nvfpscap' } else { 'gamefpscapguide' }
        New-GameRecommendation $action "Limite de FPS para uma tela de $rate Hz" $reason
    } else {
        New-GameRecommendation 'refresh' 'Verifique a frequência do monitor' 'O Windows não informou a frequência da tela principal. Confira a tela em que você joga antes de escolher um limite de FPS.'
    }

    if ($Profile.GpuCount -gt 1) {
        New-GameRecommendation 'gamegpu' 'Confirme qual GPU renderiza o jogo' 'O Windows reportou mais de um adaptador. Aplique a preferência de alto desempenho ao executável escolhido e confira no jogo qual GPU foi selecionada.'
    } else {
        switch ($Profile.GPUVendor) {
            NVIDIA { New-GameRecommendation 'gamelowlatency' 'Teste NVIDIA Reflex quando disponível' 'O scanner encontrou uma GPU NVIDIA. Em jogos compatíveis, compare com Reflex ligado usando a mesma cena e o mesmo limite de FPS.' }
            AMD { New-GameRecommendation 'gamelowlatency' 'Teste Radeon Anti-Lag quando compatível' 'O scanner encontrou uma GPU AMD. Confira o suporte do modelo e do jogo. Experimente pelo perfil individual do jogo para comparar a resposta.' }
            default { New-GameRecommendation 'gamelowlatency' 'Teste a opção de baixa latência do jogo' 'Abra as opções de vídeo do jogo e verifique quais recursos aparecem para o driver e a GPU instalados. Compare cada recurso com a configuração original.' }
        }
    }

    if ($Profile.VRAMGiB) {
        $memory = ([double]$Profile.VRAMGiB).ToString('0.#', $number)
        $texture = if ($Profile.VRAMGiB -le 6) { 'Comece em texturas baixas ou médias nos títulos mais pesados e observe travadas enquanto se movimenta.' }
            else { 'Use os requisitos do título para escolher a qualidade de textura e observe picos de memória e travadas nas cenas mais pesadas.' }
        New-GameRecommendation 'gamepreset' "Qualidade de textura com $memory GiB de VRAM" $texture
    }
    if ($Profile.PrimaryWidth -gt 1920 -or $Profile.PrimaryHeight -gt 1080) {
        New-GameRecommendation 'gamesuperres' 'Compare escalonamento na resolução da sua tela' "A tela principal está em $($Profile.PrimaryWidth) × $($Profile.PrimaryHeight). Se a GPU limitar o FPS, compare a resolução nativa com um modo de qualidade de super-resolução oferecido pelo jogo."
    }
    if ($Profile.RAMGiB -and $Profile.RAMGiB -le 16) {
        $memory = ([double]$Profile.RAMGiB).ToString('0.#', $number)
        New-GameRecommendation 'startup' "Reduza a disputa por $memory GiB de RAM" 'Confira a aba Desempenho do Gerenciador de Tarefas durante o jogo. Se a memória ficar cheia, feche apps pesados e revise a inicialização antes de mudar a qualidade gráfica.'
    }
    if ($Profile.CPUCores -and $Profile.CPUCores -le 6) {
        New-GameRecommendation 'gamebenchmark' 'Compare CPU e GPU na mesma cena' "O Windows reportou $($Profile.CPUCores) núcleos de CPU. Se alguns núcleos estiverem saturados enquanto a GPU tem folga, compare opções como multidões, distância ou simulação, quando o jogo oferecer."
    }
    if ($Profile.HasSSD -eq $true) {
        New-GameRecommendation 'gamebenchmark' 'Verifique em qual unidade o jogo está' 'Há um SSD detectado. Em jogos com carregamento contínuo, confira se a instalação está no SSD e compare os tempos de carregamento e as travadas com a mesma sessão de teste.'
    }
    if ($Profile.HasEthernetLink -eq $false) {
        New-GameRecommendation 'gamebenchmark' 'Compare a estabilidade da sua conexão' 'O Windows não reportou uma Ethernet ativa. Se você joga online, compare a perda de pacotes e as oscilações no diagnóstico do jogo com a conexão atual e, se disponível, um cabo.'
    }
    New-GameRecommendation 'gamebenchmark' 'Registre uma comparação antes e depois' 'Use a mesma fase ou rota e mude uma opção por vez. Compare FPS, regularidade dos quadros e ping separadamente.'
}
