//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

/// A non-modal banner that surfaces a transient error message at the
/// bottom of a screen (§10.3.5).
struct ToastView: View {
	let message: String

	var body: some View {
		Label(message, systemImage: "exclamationmark.circle.fill")
			.font(.callout)
			.foregroundStyle(.primary)
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(.regularMaterial, in: .capsule)
			.shadow(color: .black.opacity(0.15), radius: 8, y: 2)
	}
}

extension View {
	/// Overlays a transient error toast at the bottom of the view while
	/// `message` is non-`nil`, then auto-dismisses it.
	///
	/// - Parameters:
	///   - message: The localized error to show, or `nil` for no toast.
	///   - onDismiss: Invoked when the toast auto-dismisses so the caller
	///     can clear the state that drives `message`.
	func toast(message: String?, onDismiss: @escaping () -> Void) -> some View {
		modifier(ToastModifier(message: message, onDismiss: onDismiss))
	}
}

private struct ToastModifier: ViewModifier {
	let message: String?
	let onDismiss: () -> Void

	func body(content: Content) -> some View {
		content
			.overlay(alignment: .bottom) {
				if let message {
					ToastView(message: message)
						.padding(.bottom, 24)
						.transition(.move(edge: .bottom).combined(with: .opacity))
						.task(id: message) {
							// A fresh `message` cancels and restarts this task,
							// so each toast gets its own full dwell time.
							try? await Task.sleep(for: .seconds(3))
							guard !Task.isCancelled else { return }
							onDismiss()
						}
				}
			}
			.animation(.easeInOut(duration: 0.25), value: message)
	}
}
