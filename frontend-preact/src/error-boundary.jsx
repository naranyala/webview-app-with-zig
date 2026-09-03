import { Component } from 'preact';

/**
 * Production error boundary / fallback screen.
 * Catches render or backend-driven crashes in the toolkit shell and offers
 * a safe recovery instead of a blank WebView.
 */
export class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error) {
    if (typeof console !== 'undefined' && error) {
      console.error('[WebView App] Unhandled UI error:', error);
    }
  }

  handleReset = () => {
    this.setState({ error: null });
    if (typeof window !== 'undefined' && window.location) {
      window.location.reload();
    }
  };

  render(props, state) {
    if (state.error) {
      const message =
        state.error instanceof Error
          ? state.error.message
          : String(state.error ?? 'Unknown error');
      return (
        <div className="shell">
          <main className="launcher-main" role="alert">
            <p className="eyebrow">Toolkit</p>
            <h1>Something went wrong</h1>
            <p className="lede">
              The workspace hit an unexpected error and stopped rendering.
            </p>
            <p className="error">{message}</p>
            <button type="button" onClick={this.handleReset}>
              Reload workspace
            </button>
          </main>
        </div>
      );
    }
    return props.children;
  }
}
