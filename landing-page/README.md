# FameFit Landing Page

A sleek, modern landing page for FameFit - designed to match Apple's aesthetic while showcasing the app's unique gamification features.

## 🚀 Quick Deploy to AWS S3

### Prerequisites
- AWS CLI installed and configured
- S3 bucket created
- Route53 domain configured (optional)

### Deployment Steps

1. **Create S3 Bucket** (if not already created):
```bash
aws s3 mb s3://famefit-landing --region us-east-1
```

2. **Configure bucket for static website hosting**:
```bash
aws s3 website s3://famefit-landing \
  --index-document index.html \
  --error-document error.html
```

3. **Set bucket policy for public access**:
```bash
aws s3api put-bucket-policy --bucket famefit-landing --policy '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::famefit-landing/*"
    }
  ]
}'
```

4. **Deploy the files**:
```bash
# From the landing-page directory
aws s3 sync . s3://famefit-landing \
  --exclude ".git/*" \
  --exclude "README.md" \
  --exclude ".DS_Store" \
  --cache-control "max-age=86400"
```

5. **Set up CloudFront (recommended for performance)**:
```bash
aws cloudfront create-distribution \
  --origin-domain-name famefit-landing.s3-website-us-east-1.amazonaws.com \
  --default-root-object index.html
```

6. **Configure Route53** (if using custom domain):
- Create A record pointing to CloudFront distribution
- Or point directly to S3 website endpoint

## 🎨 Design Features

- **Apple-inspired aesthetic** with blur effects and smooth animations
- **Responsive design** that works on all devices
- **Purple gradient branding** consistent with FameFit's identity
- **Floating device mockups** showcasing iPhone and Apple Watch
- **Smooth scroll animations** and parallax effects
- **Optimized for performance** with minimal dependencies

## 📁 Structure

```
landing-page/
├── index.html          # Main HTML file
├── css/
│   └── styles.css      # All styles (no dependencies)
├── js/
│   └── animations.js   # Vanilla JS animations
└── images/            # (Add app screenshots here if needed)
```

## 🔧 Customization

### Update App Store Link
Replace placeholder App Store links in `index.html`:
```html
<a href="https://apps.apple.com/app/famefit" class="cta-button">
```

### Add Real Screenshots
1. Export app screenshots from Xcode
2. Place in `images/` directory
3. Update mockup divs in HTML:
```html
<img src="images/iphone-screenshot.png" alt="FameFit iPhone">
```

### Modify Colors
Edit CSS variables in `styles.css`:
```css
:root {
    --primary: #7C3AED;     /* Purple */
    --accent: #F59E0B;      /* Orange */
}
```

## 📱 Features Highlighted

- **XP System** - Transform workouts into experience points
- **Challenge Friends** - Stake XP in competitions
- **Apple Watch Integration** - Seamless sync between devices
- **HealthKit Integration** - Works with Apple's ecosystem

## 🚦 Performance

- **No build step required** - Pure HTML/CSS/JS
- **No dependencies** - Everything works out of the box
- **Optimized assets** - Minimal file sizes
- **CDN-ready** - Configure CloudFront for global delivery

## 📊 Analytics (Optional)

Add Google Analytics or similar by inserting before `</head>`:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

## 🔍 SEO

The page includes:
- Meta descriptions
- Open Graph tags
- Semantic HTML
- Fast load times
- Mobile-responsive design

## 💡 Tips

1. **Test locally** before deploying:
```bash
python3 -m http.server 8000
# Visit http://localhost:8000
```

2. **Compress images** before adding to reduce load times

3. **Enable CloudFront compression** for better performance

4. **Monitor S3 costs** - enable logging if needed

## 📄 License

Part of the FameFit project. All rights reserved.