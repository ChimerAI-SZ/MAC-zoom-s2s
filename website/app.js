// BabelAI Website - Interactive Elements & Animations

(function() {
  'use strict';

  // Smooth scroll for navigation links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // Enhanced Navigation scroll effect
  const nav = document.querySelector('.nav');
  let lastScroll = 0;
  let scrollTimeout;
  
  // Add smooth transition to nav
  nav.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
  
  window.addEventListener('scroll', () => {
    // Clear timeout to debounce
    if (scrollTimeout) {
      window.cancelAnimationFrame(scrollTimeout);
    }
    
    scrollTimeout = window.requestAnimationFrame(() => {
      const currentScroll = window.pageYOffset;
      
      // Background opacity based on scroll
      if (currentScroll > 100) {
        nav.style.background = 'rgba(0, 0, 0, 0.98)';
        nav.style.backdropFilter = 'saturate(180%) blur(30px)';
        nav.style.borderBottom = '1px solid rgba(255, 255, 255, 0.05)';
      } else {
        nav.style.background = 'rgba(0, 0, 0, 0.8)';
        nav.style.backdropFilter = 'saturate(180%) blur(20px)';
        nav.style.borderBottom = '1px solid var(--color-gray-900)';
      }
      
      // Hide/Show on scroll direction
      if (currentScroll > lastScroll && currentScroll > 300) {
        // Scrolling down & past 300px
        nav.style.transform = 'translateY(-100%)';
      } else {
        // Scrolling up or at top
        nav.style.transform = 'translateY(0)';
      }
      
      lastScroll = currentScroll;
    });
  }, { passive: true });

  // Enhanced Terminal animation with typing effect
  const terminalLines = document.querySelectorAll('.terminal-line');
  const observerOptions = {
    threshold: 0.5,
    rootMargin: '0px 0px -100px 0px'
  };

  const terminalObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting && !entry.target.classList.contains('typed')) {
        const terminal = entry.target.closest('.terminal');
        if (terminal && !terminal.classList.contains('typing-started')) {
          terminal.classList.add('typing-started');
          const lines = terminal.querySelectorAll('.terminal-line:not(.terminal-spacer)');
          
          lines.forEach((line, index) => {
            setTimeout(() => {
              line.style.opacity = '1';
              line.style.transform = 'translateY(0)';
              line.style.animation = 'fadeInUp 0.5s ease forwards';
            }, index * 200);
          });
        }
      }
    });
  }, observerOptions);

  terminalLines.forEach(line => {
    if (!line.classList.contains('terminal-spacer')) {
      line.style.opacity = '0';
      line.style.transform = 'translateY(10px)';
    }
    terminalObserver.observe(line);
  });

  // Add fadeInUp animation
  const style = document.createElement('style');
  style.textContent = `
    @keyframes fadeInUp {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
  `;
  document.head.appendChild(style);

  // Stats Counter Animation
  const animateValue = (element, start, end, duration, suffix = '') => {
    const startTimestamp = Date.now();
    const step = () => {
      const timestamp = Date.now();
      const progress = Math.min((timestamp - startTimestamp) / duration, 1);
      const value = Math.floor(progress * (end - start) + start);
      element.textContent = value + suffix;
      
      if (progress < 1) {
        window.requestAnimationFrame(step);
      }
    };
    window.requestAnimationFrame(step);
  };

  const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting && !entry.target.classList.contains('animated')) {
        entry.target.classList.add('animated');
        const statValues = entry.target.querySelectorAll('.stat-value');
        
        statValues.forEach(stat => {
          const text = stat.textContent;
          if (text.includes('<')) {
            // Handle <1.5s
            stat.innerHTML = '<span style="opacity: 0">&lt;</span>1.5s';
            setTimeout(() => {
              const span = stat.querySelector('span');
              span.style.transition = 'opacity 0.5s';
              span.style.opacity = '1';
            }, 500);
          } else if (text.includes('%')) {
            // Handle 98%+
            const num = parseInt(text);
            stat.textContent = '0%+';
            setTimeout(() => animateValue(stat, 0, num, 1500, '%+'), 300);
          } else if (text.includes('kHz')) {
            // Handle 48kHz
            const num = parseInt(text);
            stat.textContent = '0kHz';
            setTimeout(() => animateValue(stat, 0, num, 1000, 'kHz'), 200);
          }
        });
      }
    });
  }, { threshold: 0.5 });

  const heroStats = document.querySelector('.hero-stats');
  if (heroStats) {
    statsObserver.observe(heroStats);
  }

  // Feature cards animation with stagger effect
  const featureCards = document.querySelectorAll('.feature-card');
  const featureObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry, index) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }, index * 100);
      }
    });
  }, observerOptions);

  featureCards.forEach(card => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(30px)';
    card.style.transition = 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
    featureObserver.observe(card);
  });

  // Download button tracking
  const downloadBtns = document.querySelectorAll('[download]');
  downloadBtns.forEach(btn => {
    btn.addEventListener('click', function() {
      // Track download (placeholder for analytics)
      console.log('Download initiated:', this.href);
      
      // Show success message
      const originalText = this.innerHTML;
      this.innerHTML = '<svg class="btn-icon" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg> Starting Download...';
      setTimeout(() => {
        this.innerHTML = originalText;
      }, 3000);
    });
  });

  // Feedback form handling
  const feedbackForm = document.getElementById('feedbackForm');
  const feedbackStatus = document.getElementById('feedback-status');
  
  if (feedbackForm) {
    feedbackForm.addEventListener('submit', async function(e) {
      e.preventDefault();
      
      const formData = new FormData(this);
      const data = Object.fromEntries(formData);
      
      // Show loading state
      feedbackStatus.textContent = 'Sending feedback...';
      feedbackStatus.className = 'feedback-status';
      
      // Simulate API call (replace with actual endpoint)
      try {
        // For demo purposes, we'll use a timeout
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // In production, replace with:
        // const response = await fetch('YOUR_API_ENDPOINT', {
        //   method: 'POST',
        //   headers: { 'Content-Type': 'application/json' },
        //   body: JSON.stringify(data)
        // });
        
        // Success message
        feedbackStatus.textContent = 'Thank you for your feedback! We\'ll get back to you soon.';
        feedbackStatus.className = 'feedback-status success';
        
        // Reset form
        this.reset();
        
        // Clear message after 5 seconds
        setTimeout(() => {
          feedbackStatus.textContent = '';
        }, 5000);
        
      } catch (error) {
        // Error message
        feedbackStatus.textContent = 'Something went wrong. Please try again or email us directly.';
        feedbackStatus.className = 'feedback-status error';
      }
    });
  }

  // Dynamic copyright year
  const copyrightYear = document.querySelector('.footer-copyright');
  if (copyrightYear) {
    const year = new Date().getFullYear();
    copyrightYear.innerHTML = copyrightYear.innerHTML.replace('2025', year);
  }

  // Preload fonts
  const preloadFont = (href) => {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.as = 'font';
    link.type = 'font/woff2';
    link.href = href;
    link.crossOrigin = 'anonymous';
    document.head.appendChild(link);
  };

  // Add Inter font
  const fontLink = document.createElement('link');
  fontLink.href = 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap';
  fontLink.rel = 'stylesheet';
  document.head.appendChild(fontLink);

  // Performance monitoring (placeholder)
  if (window.performance && window.performance.timing) {
    window.addEventListener('load', () => {
      const timing = window.performance.timing;
      const loadTime = timing.loadEventEnd - timing.navigationStart;
      console.log('Page load time:', loadTime + 'ms');
    });
  }

  // Handle broken download links gracefully
  window.addEventListener('error', (e) => {
    if (e.target.tagName === 'A' && e.target.hasAttribute('download')) {
      e.preventDefault();
      console.error('Download link broken:', e.target.href);
      // Fallback to email
      window.location.href = 'mailto:support@s2s.app?subject=Download%20Issue';
    }
  }, true);

  // Mobile menu toggle (for future implementation)
  const mobileMenuToggle = () => {
    const nav = document.querySelector('.nav-menu');
    if (nav) {
      nav.classList.toggle('nav-menu--open');
    }
  };

  // Expose for potential mobile menu button
  window.S2S = {
    toggleMobileMenu: mobileMenuToggle
  };

})();