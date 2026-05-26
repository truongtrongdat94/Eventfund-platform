import React from 'react';
import { Link } from 'react-router-dom';

export const Footer: React.FC = () => {
  return (
    <footer className="bg-slate-950 border-t border-slate-800 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid md:grid-cols-4 gap-8 mb-8">
          <div>
            <h3 className="font-semibold text-white mb-4">EventChain</h3>
            <p className="text-sm text-slate-400">The future of event ticketing on Web3.</p>
          </div>
          <div>
            <h4 className="font-semibold text-white mb-4">Platform</h4>
            <ul className="space-y-2 text-sm text-slate-400">
              <li><Link to="/explore" className="hover:text-white transition-colors">Explore Events</Link></li>
              <li><Link to="/marketplace" className="hover:text-white transition-colors">Marketplace</Link></li>
              <li><Link to="/about" className="hover:text-white transition-colors">About</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-white mb-4">Support</h4>
            <ul className="space-y-2 text-sm text-slate-400">
              <li><Link to="/faq" className="hover:text-white transition-colors">FAQ</Link></li>
              <li><Link to="/terms" className="hover:text-white transition-colors">Terms</Link></li>
              <li><Link to="/privacy" className="hover:text-white transition-colors">Privacy</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-white mb-4">Connect</h4>
            <ul className="space-y-2 text-sm text-slate-400">
              <li><a href="https://www.facebook.com/thanhphat.kieu.942/" className="hover:text-white transition-colors">Facebook</a></li>
              <li><a href="mailto:truongtrongdat94@gmail.com" className="hover:text-white transition-colors">Gmail</a></li>
              <li><a href="https://github.com/truongtrongdat94/Eventfund-platform" className="hover:text-white transition-colors">GitHub</a></li>
            </ul>
          </div>
        </div>
        <div className="pt-8 border-t border-slate-800 text-center text-sm text-slate-500">
          © 2026 EventChain. All rights reserved.
        </div>
      </div>
    </footer>
  );
};
