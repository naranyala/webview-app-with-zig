import { render } from 'preact';
import './styles.css';
import './toolkit.css';
import { App } from './App.jsx';
import { ErrorBoundary } from './error-boundary.jsx';

render(
  <ErrorBoundary>
    <App />
  </ErrorBoundary>,
  document.getElementById('app')
);
