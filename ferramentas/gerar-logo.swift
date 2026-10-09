#!/usr/bin/env swift
// CaixaPreta — esferográfica azul sobre papel creme.
// Sem dependências. Uso: swift /caminho/gerar-logo.swift
// A saída fica sempre ao lado deste script. Sementes fixas: resultado reproduzível.
// v1: caixa com pequeno sinal de registro; v2: somente a caixa.
import AppKit
import CoreGraphics

let destino = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let papel = CGColor(srgbRed: 0.973, green: 0.949, blue: 0.894, alpha: 1)
struct Sorteio {
    var estado: UInt64 = 20261009
    mutating func entre(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        estado &+= 0x9E3779B97F4A7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return a + (b-a) * CGFloat(z >> 11) / CGFloat(UInt64(1) << 53)
    }
}
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x:x,y:y) }

func desenhar(lado: Int, sinal: Bool) throws -> Data {
    var rng = Sorteio()
    let ctx = CGContext(data:nil, width:lado, height:lado, bitsPerComponent:8,
        bytesPerRow:0, space:CGColorSpace(name:CGColorSpace.sRGB)!,
        bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x:0,y:CGFloat(lado))
    ctx.scaleBy(x:CGFloat(lado)/1024,y:CGFloat(-lado)/1024)
    ctx.setFillColor(papel)
    ctx.fill(CGRect(x:0,y:0,width:1024,height:1024))

    ctx.translateBy(x:512,y:512)
    ctx.scaleBy(x:1.22,y:1.22)
    ctx.translateBy(x:-512,y:-512)

    // A linha vira uma fita preenchida: largura e desvio variam lentamente,
    // sem bolinhas nas emendas. O tremido é pequeno, sem ruído artificial.
    func caneta(_ pontos: [CGPoint], largura: CGFloat = 6.8,
                tremido: CGFloat = 3.3, alfa: CGFloat = 0.84) {
        let f1 = rng.entre(0,2 * .pi), f2 = rng.entre(0,2 * .pi)
        let desloc = rng.entre(-1.0,1.0)
        var linha: [CGPoint] = []
        var dist: CGFloat = 0
        for (a,b) in zip(pontos,pontos.dropFirst()) {
            let dx = b.x-a.x, dy = b.y-a.y, len = max(0.001,hypot(dx,dy))
            let n = max(2,Int(len/3))
            for i in (linha.isEmpty ? 0 : 1)...n {
                let t = CGFloat(i)/CGFloat(n), s = dist + t*len
                let w = tremido * (0.65*sin(s/39+f1)+0.25*sin(s/13+f2)) + desloc
                linha.append(p(a.x+dx*t-dy/len*w,a.y+dy*t+dx/len*w))
            }
            dist += len
        }
        var esq:[CGPoint] = [], dir:[CGPoint] = []
        for (i,pt) in linha.enumerated() {
            let a = linha[max(0,i-1)], b = linha[min(linha.count-1,i+1)]
            let dx = b.x-a.x, dy = b.y-a.y, len = max(0.001,hypot(dx,dy))
            let t = CGFloat(i)/CGFloat(linha.count-1)
            let ponta = min(1,min(t,1-t)*dist/9)
            let w = largura/2 * (0.78+0.22*sin(t*13+f1)) * (0.6+0.4*ponta)
            esq.append(p(pt.x-dy/len*w,pt.y+dx/len*w))
            dir.append(p(pt.x+dy/len*w,pt.y-dx/len*w))
        }
        ctx.setFillColor(CGColor(srgbRed:0.105,green:0.205,blue:0.57,alpha:alfa))
        ctx.addLines(between:esq+dir.reversed())
        ctx.closePath(); ctx.fillPath()
    }
    // Proporções de uma pequena caixa de registro; perspectiva baixa, sem
    // cubo isométrico perfeito. A face escura é feita só de riscos de tinta.
    let a = p(227,408), b = p(374,301), c = p(795,355)
    let d = p(650,465), e = p(646,727), f = p(231,668), g = p(790,615)
    ctx.saveGState()
    ctx.addLines(between:[p(654,467),p(790,361),p(785,613),p(650,719)])
    ctx.closePath(); ctx.clip()
    var x: CGFloat = 620
    while x < 965 {
        let j = rng.entre(-3,3)
        caneta([p(x+j,328+rng.entre(-25,25)),p(x-136+rng.entre(-16,16),753+rng.entre(-20,20))],
               largura:rng.entre(2.3,4.0),tremido:2.6,alfa:0.78)
        x += rng.entre(4.8,8.0)
    }
    var y: CGFloat = 495
    while y < 805 {
        caneta([p(634+rng.entre(-10,14),y),p(816,y-62+rng.entre(-20,20))],
               largura:rng.entre(1.7,2.6),tremido:1.5,alfa:0.53)
        y += rng.entre(10,20)
    }
    ctx.restoreGState()

    // Levantar a caneta entre as arestas preserva o ritmo de um esboço.
    caneta([a,b,c],largura:6.5)
    caneta([c,d,a],largura:7.1)
    caneta([a,f,e],largura:7.5)
    caneta([d,e,g,c],largura:7.5)
    // Poucos repasses leves, incompletos e desalinhados; sem contorno duplo uniforme.
    caneta([p(233,405),p(368,298),p(466,312)],largura:2.0,tremido:2.1,alfa:0.50)
    caneta([p(238,674),p(410,698),p(565,718)],largura:1.9,tremido:1.8,alfa:0.45)
    caneta([p(655,480),p(653,623)],largura:2.2,tremido:1.6,alfa:0.48)
    caneta([p(285,421),p(453,443),p(588,459)],largura:1.8,tremido:3.3,alfa:0.4)
    caneta([p(228,436),p(230,537)],largura:1.5,tremido:3,alfa:0.42)
    if sinal {
        // Um único detalhe: sinal curto, deslocado pela perspectiva da face.
        caneta([p(352,551),p(402,558),p(420,536),p(441,593),
                p(460,555),p(478,569),p(530,576)],largura:6.5,tremido:1.1,alfa:0.88)
    }
    let rep = NSBitmapImageRep(cgImage:ctx.makeImage()!)
    return rep.representation(using:.png,properties:[:])!
}

// Renderização em 4× e redução CoreGraphics: as hachuras sobrevivem em 64 px
// como densidade de tinta, com antialiasing estável e sem serrilhado.
func reduzir(_ data: Data, lado: Int) -> Data {
    let src = NSBitmapImageRep(data:data)!.cgImage!
    let ctx = CGContext(data:nil,width:lado,height:lado,bitsPerComponent:8,bytesPerRow:0,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(src,in:CGRect(x:0,y:0,width:lado,height:lado))
    return NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!
}
for (nome,sinal) in [("v1",true),("v2",false)] {
    let master = try desenhar(lado:4096,sinal:sinal)
    for lado in [1024,180,64] {
        let png = reduzir(master,lado:lado)
        if lado == 180 { try png.write(to:destino.appendingPathComponent("\(nome)-180.png")) }
        if nome == "v1" { try png.write(to:destino.appendingPathComponent("logo-\(lado).png")) }
    }
}
print("Gerados logo-{1024,180,64}.png e v{1,2}-180.png em \(destino.path)")
