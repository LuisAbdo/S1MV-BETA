# S1MV-BETA — Sobreviva a um Milhão de Veritys

Repositório dedicado às atualizações do projeto.

Jogo de Roblox de sobrevivência por waves: os jogadores defendem o **Núcleo** de hordas de
Veritys, compram armas por tier, constroem defesas na Loja do Núcleo, usam classes com
habilidades e evoluem a conta no **Main Lobby** (gemas, classes, armas, recompensas diárias).

## Estrutura

O código é exportado do Roblox Studio seguindo a convenção do [Rojo](https://rojo.space):

| Extensão       | Tipo no Studio |
|----------------|----------------|
| `.server.lua`  | Script         |
| `.client.lua`  | LocalScript    |
| `.lua`         | ModuleScript   |

As pastas espelham a hierarquia do Studio (`ServerScriptService`, `ReplicatedStorage`, `StarterPlayer`…).

```
missao/      place da missão (mapa, waves, Núcleo, loja, armas, classes)
main-lobby/  place do Main Lobby (perfil, lojas, classes, grupos e teleporte)
```

> Mapas, modelos e sons ficam no Roblox (não estão neste repositório) — aqui está só o código.

## Como se joga (modo sobrevivência)

Inspirado em *99 Noites na Floresta*:

- **Dia (mais curto):** sair da base com o **machado**, derrubar árvores e quebrar rochas.
  Toras e pedras são arrastadas (clique e segure) ou guardadas na mochila (F, até 5).
  Clicar no Núcleo **suga** tudo para o **estoque** do time.
- **Construir:** as estruturas da Loja do Núcleo custam **madeira e pedra** do estoque.
  O **dinheiro** ($ dos abates) fica para armas, vida e evolução do Núcleo.
- **Noite (mais longa):** a horda de Veritys ataca o Núcleo e recua ao amanhecer. Quem estiver
  longe da base pode ser caçado pelo **Verity Boss** — ele só desiste quando o alvo volta
  para perto do Núcleo.
- **Dias:** a noite acaba quando a horda inteira morre; o HUD só conta DIA 1, DIA 2…
- **Mercador:** uma casa nasce no mapa com um NPC que vende mochila maior, machado afiado e
  o minimapa, pagos com madeira e pedra do estoque.
- **Glitcity (noite 15):** primeiro boss, com cutscene, pulsos EMP nas torres e barreiras
  de voxel. No Studio, `/glitcity` chama ele na hora.
- **Mapa:** gerado em chunks conforme os jogadores andam, até uma parede de neblina
  (~500 studs). Números em `Config/Sobrevivencia`.

## Arquitetura da missão

- `ServerScriptService/Bootstrap.server.lua` carrega os serviços de `Services/` em ordem
  (`Init()` de todos, depois `Start()`).
- `ReplicatedStorage/Shared/Config/*` reúne **todos os números do jogo** (vida, dano, custos,
  waves, sons). Para balancear, mexa só ali.
- `StarterPlayer/StarterPlayerScripts/*Cliente` cuidam de interface, efeitos e sons; o servidor
  revalida todas as compras e ações.

## Segurança

Nunca use `require(<número>)` nem modelos grátis com scripts. Um plugin malicioso já tentou
injetar `require(5355299916)` no `Bootstrap` — se aparecer de novo, remova o plugin
(Plugins → Manage Plugins) antes de publicar.
