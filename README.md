<p align="center"><img src="docs/logo.png" width="160" alt="Logo da CaixaPreta: uma caixa desenhada à caneta azul, com um sinal de batimento"></p>

# CaixaPreta

Diagnóstico de apps iOS sem print. O app anota o que acontece. Quando ele
fecha, trava ou algo quebra, você lê no Mac o que houve.

- Grava no aparelho e copia para a pasta do app no seu iCloud Drive. Sem
  servidor e sem serviço de terceiros.
- Só aceita códigos técnicos: telefone, CPF, nome e frase são recusados.
- Diz como cada uso do app terminou (caiu com o app na tela, fechado no
  fundo), quanta memória usou e as falhas do MetricKit com o nome da função.

Swift 6, iOS 17+ e macOS 14+, sem dependências.

## No app

1. Adicione o pacote `https://github.com/jrflga/caixa-preta`, a partir de
   `0.1.0`, com o produto `CaixaPreta`.
2. Ative o iCloud com o serviço iCloud Documents e um container, por exemplo
   `iCloud.com.exemplo.app`. No `Info.plist`, torne a pasta pública: só assim
   ela aparece no iCloud Drive do Mac.

   ```xml
   <key>NSUbiquitousContainers</key>
   <dict>
       <key>iCloud.com.exemplo.app</key>
       <dict>
           <key>NSUbiquitousContainerIsDocumentScopePublic</key>
           <true/>
           <key>NSUbiquitousContainerName</key>
           <string>Exemplo</string>
           <key>NSUbiquitousContainerSupportedFolderLevels</key>
           <string>Any</string>
       </dict>
   </dict>
   ```

3. Ligue a caixa na abertura, antes de tudo, e anote o que importa:

   ```swift
   import CaixaPreta

   CaixaPreta.ligar(app: "Exemplo", containerDoICloud: "iCloud.com.exemplo.app")

   CaixaPreta.anotar("pagina.situacao", ["site": "loja", "situacao": "conectado"])
   CaixaPreta.anotar("busca.leitura", ["ok": false, "ms": 830])
   ```

4. Para quem usa o app com outra conta do iCloud, ofereça o arquivo:

   ```swift
   @State private var diagnostico: URL?

   // Na tela de ajustes:
   if let diagnostico {
       ShareLink("Enviar diagnóstico", item: diagnostico)
   }
   // …
   .task { diagnostico = await CaixaPreta.arquivoParaEnviar() }
   ```

## O que se anota

- Nomes de evento e de campo seguem `^[a-z][a-z0-9_.-]{0,39}$`.
- Valores podem ser:
  - texto no mesmo formato;
  - inteiro;
  - número com vírgula;
  - sim/não.
- Números de 1 bilhão para cima não entram (é o tamanho de um telefone ou de
  um CPF).
- Cada evento leva até 12 campos.
- O que não passa vira `caixa.recusado`, com o evento e o campo, e nunca com
  o valor.
- No resumo, aparece como problema:
  - evento `*.problema` ou `*.erro`;
  - campo `ok` falso;
  - valor de texto que começa com `erro` ou `sem_`.

A caixa também anota sozinha:
- `sessao.comecou`;
- `sessao.anterior`, que diz como terminou o uso de antes;
- `sessao.frente` e `sessao.fundo`;
- `sessao.aviso_de_memoria`;
- `ios.falha` e `ios.fechamentos`, vindos do MetricKit;
- `caixa.sem_icloud` e `caixa.limite`.

Ela guarda 14 dias e até 5 MB de anotações por dia.

## Nos testes do app

```swift
let eventos = await CaixaPreta.capturando {
    await pagina.verificar()
}
#expect(eventos.map(\.nome) == ["pagina.situacao"])
```

A captura vê só o que roda na própria tarefa: testes em paralelo não se
misturam.

## No Mac

```bash
swift build -c release
.build/release/caixa-preta resumo Exemplo --dias 2 --simbolos <pasta com os dSYMs>
.build/release/caixa-preta eventos Exemplo --desde 14:30
.build/release/caixa-preta resumo Exemplo --arquivo CaixaPreta-Exemplo-….jsonl
```

O comando procura em `~/Library/Mobile Documents/iCloud~*/Documents/CaixaPreta/`.
Primeiro baixa o que o iCloud ainda não trouxe; depois mostra cada uso:

```
Uso 7c1d9e02 · 09/10 14:20:00 → 14:31:00 (11 min) · versão 1.0 (7) · iOS 27.0
  Como terminou: fechado logo depois de ir para o fundo; abriu de novo 2 min depois do último sinal.
  Memória: pico 612 MB.
  Falha do iOS: falha · sinal 11 (SIGSEGV: acesso inválido à memória) · …
    0  Exemplo  Pagina.verificar() (in Exemplo) (Pagina.swift:147)
  Últimos passos:
    14:31:00 sessao.fundo memoria_mb=612
```

Os nomes das funções vêm do dSYM da build, achado pelo UUID em `--simbolos`
e nos arquivos do Xcode.

## Licença

MIT. A logo sai de `ferramentas/gerar-logo.swift`.
