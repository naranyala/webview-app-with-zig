declare global {
  interface Window {
    increment(delta: number): Promise<number>;
    reset(): Promise<number>;
    getSystemInfo(): Promise<string>;
    getTimestamp(): Promise<string>;
    minimizeWindow(): Promise<void>;
    maximizeWindow(): Promise<void>;
    restoreWindow(): Promise<void>;
    enterFullscreen(): Promise<void>;
    exitFullscreen(): Promise<void>;
    closeWindow(): Promise<void>;
  }
}

export {};
