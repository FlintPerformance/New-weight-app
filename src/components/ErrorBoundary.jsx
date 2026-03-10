import React from 'react';

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('App crash caught by ErrorBoundary:', error, errorInfo);
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  handleHardReset = () => {
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-surface flex items-center justify-center p-6">
          <div className="text-center max-w-sm">
            <h1 className="font-logo text-4xl font-extrabold text-accent mb-4">
              steady
            </h1>
            <p className="text-cream/60 text-sm mb-6">Something went wrong. Your data is safe.</p>
            <div className="flex gap-3 justify-center">
              <button
                onClick={this.handleReset}
                className="bg-accent hover:bg-accent-dark text-white px-5 py-2.5 rounded-sm font-semibold text-sm transition-colors"
              >
                Try Again
              </button>
              <button
                onClick={this.handleHardReset}
                className="bg-surface-mid hover:bg-surface-up text-cream/60 px-5 py-2.5 rounded-sm text-sm border border-black/10 transition-colors"
              >
                Reload App
              </button>
            </div>
            {this.state.error && (
              <p className="text-cream/20 text-[10px] mt-4 break-all">
                {this.state.error.message}
              </p>
            )}
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
