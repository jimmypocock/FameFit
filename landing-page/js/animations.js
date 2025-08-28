// Smooth scroll animation for counting numbers
function animateValue(element, start, end, duration) {
    const range = end - start;
    const increment = end > start ? 1 : -1;
    const stepTime = Math.abs(Math.floor(duration / range));
    let current = start;
    
    const timer = setInterval(() => {
        current += increment;
        element.textContent = current;
        
        if (current === end) {
            clearInterval(timer);
        }
    }, stepTime);
}

// Intersection Observer for scroll animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            // Animate features
            if (entry.target.classList.contains('feature')) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
            
            // Animate stat numbers
            if (entry.target.classList.contains('stat-number')) {
                const finalValue = parseInt(entry.target.getAttribute('data-count'));
                animateValue(entry.target, 0, finalValue, 1500);
                observer.unobserve(entry.target);
            }
        }
    });
}, observerOptions);

// Observe elements when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Observe features
    const features = document.querySelectorAll('.feature');
    features.forEach(feature => observer.observe(feature));
    
    // Observe stat numbers
    const stats = document.querySelectorAll('.stat-number');
    stats.forEach(stat => observer.observe(stat));
    
    // Parallax effect for hero section (desktop only)
    const heroVisual = document.querySelector('.hero-visual');
    if (heroVisual && window.innerWidth > 968) {
        window.addEventListener('scroll', () => {
            // Only apply parallax on desktop
            if (window.innerWidth > 968) {
                const scrolled = window.pageYOffset;
                const parallaxSpeed = 0.5;
                heroVisual.style.transform = `translateY(${scrolled * parallaxSpeed}px)`;
            }
        });
    }
    
    // Navigation background on scroll
    const nav = document.querySelector('.nav');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            nav.style.background = 'rgba(236, 72, 153, 1)';
            nav.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.15)';
        } else {
            nav.style.background = 'rgba(236, 72, 153, 0.95)';
            nav.style.boxShadow = 'none';
        }
    });
    
    // Add subtle mouse movement effect to cards
    const cards = document.querySelectorAll('.card');
    cards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            
            const rotateX = (y - centerY) / 10;
            const rotateY = (centerX - x) / 10;
            
            card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.05)`;
        });
        
        card.addEventListener('mouseleave', () => {
            card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) scale(1)';
        });
    });
    
    // Smooth reveal animation for hero content
    const heroContent = document.querySelector('.hero-content');
    if (heroContent) {
        heroContent.style.opacity = '0';
        heroContent.style.transform = 'translateY(30px)';
        
        setTimeout(() => {
            heroContent.style.transition = 'all 1s ease';
            heroContent.style.opacity = '1';
            heroContent.style.transform = 'translateY(0)';
        }, 100);
    }
    
});

// Smooth scroll for anchor links (if you add any)
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});