/**
 * EventFund Platform - Frontend Application
 * Main entry point for the React application
 * 
 * 
 * 
 * 
 * 
 */

// Must be first — patches process.nextTick and other Node globals before
// Web3Auth / readable-stream bundles execute
import './polyfills'
import { createRoot } from "react-dom/client";
import { BrowserRouter } from 'react-router-dom';
import { Web3AuthProvider } from "@web3auth/modal/react";
import { web3AuthConfig } from "./app/web3auth.config";
import App from "./app/App.tsx";
import "./styles/index.css";

createRoot(document.getElementById("root")!).render(
  <BrowserRouter>
    <Web3AuthProvider config={web3AuthConfig}>
      <App />
    </Web3AuthProvider>
  </BrowserRouter>
);
