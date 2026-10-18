# Regras do projeto S1MV-BETA

## Regra principal: toda atualização vira commit

**QUALQUER atualização feita no jogo (missão ou Main Lobby) deve terminar com um commit dessa
feature neste repositório**, no mesmo turno em que a mudança foi feita — sem esperar pedido.

Fluxo depois de cada mudança no Roblox Studio:
1. Exportar do Studio **só os scripts alterados/criados/removidos** (via `execute_luau` →
   `HttpService:JSONEncode`; respostas grandes viram arquivo em `tool-results/`).
2. Conferir o tamanho em bytes contra o Studio e procurar `require(<número>)`, `getfenv`,
   `loadstring` antes de gravar. **Nunca** commitar backdoor.
3. Gravar em `missao/` ou `main-lobby/` espelhando a hierarquia do Studio
   (`.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript).
   Ignorar pastas `Backup*`.
4. **Um commit por feature**, mensagem em português no formato
   `feat(missao|lobby): <o que mudou>` / `fix(...)` / `docs: ...`, com corpo explicando o porquê.
5. Push para a branch de trabalho (`atualizacoes-out-2026` enquanto o PR #1 estiver aberto;
   depois, uma branch nova por conjunto de mudanças — ex.: `sobrevivencia-floresta`) e manter
   um PR aberto para `main`.

## Bootstrap
- `ServerScriptService/Bootstrap` limpo tem **1564 bytes** (com MercadorService e GlitcityService) e termina na linha
  `print("[Bootstrap] Servicos iniciados: " .. table.concat(ORDER, ", "))`. Qualquer coisa
  depois disso é o backdoor do plugin — apagar antes de exportar.
- Serviço novo entra na lista `ORDER` (e o tamanho de referência acima muda).

## Restrições permanentes
- Nunca usar modelos grátis com scripts nem `require()` de IDs numéricos.
- Validar tudo no servidor.
- `ReplicatedStorage/Shared/Config/Lobby.lua` deve ser idêntico nas duas places.
