// LoremIpsumView.swift — generate placeholder text in 4 styles.

import SwiftUI

struct LoremIpsumView: View {
    @State private var output: String = ""
    @State private var paragraphs: Int = 1
    private enum Style: String, CaseIterable, Identifiable {
        case lorem = "Lorem"
        case hipster = "Hipster"
        case bacon = "Bacon"
        case spaceX = "SpaceX"
        var id: String { rawValue }
    }
    @State private var style: Style = .lorem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $style) {
                    ForEach(Style.allCases) { s in Text(s.rawValue).tag(s) }
                }.labelsHidden().frame(width: 110)
                Stepper("\(paragraphs) ¶", value: $paragraphs, in: 1...8)
                    .font(.system(size: 11, weight: .heavy))
                Spacer()
                Button("Generate") { generate() }
                    .buttonStyle(.borderedProminent)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.bordered)
                    .disabled(output.isEmpty)
            }
            ScrollView {
                Text(output.isEmpty ? "Click Generate." : output)
                    .font(.system(size: 11))
                    .foregroundColor(output.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05)))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .onAppear { if output.isEmpty { generate() } }
    }

    private func generate() {
        let words = corpus[style] ?? []
        var pars: [String] = []
        for _ in 0..<paragraphs {
            let count = Int.random(in: 38...62)
            var sentences: [String] = []
            var sentence: [String] = []
            for _ in 0..<count {
                sentence.append(words.randomElement() ?? "lorem")
                if sentence.count >= Int.random(in: 6...14) {
                    var s = sentence.joined(separator: " ")
                    s = s.prefix(1).uppercased() + s.dropFirst() + "."
                    sentences.append(s)
                    sentence = []
                }
            }
            if !sentence.isEmpty {
                var s = sentence.joined(separator: " ")
                s = s.prefix(1).uppercased() + s.dropFirst() + "."
                sentences.append(s)
            }
            pars.append(sentences.joined(separator: " "))
        }
        output = pars.joined(separator: "\n\n")
    }

    // Compact word lists per style — enough variety for paragraphs.
    private let corpus: [Style: [String]] = [
        .lorem: "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua enim ad minim veniam quis nostrud exercitation ullamco laboris nisi aliquip ex ea commodo consequat duis aute irure reprehenderit in voluptate velit esse cillum eu fugiat nulla pariatur excepteur sint occaecat cupidatat non proident sunt culpa qui officia deserunt mollit anim id est laborum".split(separator: " ").map(String.init),
        .hipster: "artisan kale chips cold-brew vinyl mustache typewriter etsy small-batch farm-to-table beard pour-over ironic brined sustainable thundercats banh-mi fixie chambray hashtag flannel aesthetic tofu ramps wayfarers authentic raw denim church-key offal narwhal fanny-pack semiotics direct-trade".split(separator: " ").map(String.init),
        .bacon: "bacon ipsum dolor amet brisket short-ribs ground-round salami pancetta venison strip-steak hamburger beef-ribs t-bone pork-chop chicken turkey andouille sausage spare-ribs porchetta tongue rump alcatra ham hock burgdoggen jowl prosciutto kielbasa kevin ribeye chuck filet-mignon picanha shankle drumstick".split(separator: " ").map(String.init),
        .spaceX: "starship raptor cryogenic methane oxidizer thrust gimbal staging payload deorbit perigee apogee inclination plasma reentry telemetry yaw roll pitch nominal abort destacking strongback cradle barge autonomous propellant venting ignition liftoff stage-separation booster nominal trajectory cape canaveral starbase".split(separator: " ").map(String.init),
    ]
}
