import SwiftUI
import WebKit

/// Lecteur YouTube intégré à la fiche d'exercice, lu sur place et en plein écran à la demande.
struct DemonstrationPlayer: UIViewRepresentable {
    let embedURL: URL

    /// YouTube exige une origine identifiant l'app (erreur 153 sinon) : le format attendu
    /// pour une app native est l'identifiant de bundle en https.
    private static let origin = URL(string: "https://com.mabdpro.bodypilot")!

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        // Transparent tant que la vidéo charge : l'indicateur de chargement reste visible derrière.
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loaded != embedURL else { return }
        context.coordinator.loaded = embedURL
        view.loadHTMLString(Self.page(for: embedURL), baseURL: Self.origin)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded: URL?
    }

    private static func page(for url: URL) -> String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:transparent}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
        </head><body><iframe src="\(url.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>
        """
    }
}
