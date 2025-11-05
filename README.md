# LastMinute 🚗

A comprehensive multi-platform transportation and marketplace application built with Django and Flutter.

## 📖 About LastMinute

**LastMinute** is an innovative multi-service platform that combines on-demand transportation with a marketplace ecosystem, designed to provide seamless and secure experiences for customers, partners (drivers), and sellers.

### 🎯 Vision
To create a unified platform where users can access transportation services and marketplace functionality, all while ensuring the highest standards of safety, reliability, and user experience.

### 🌟 What Makes LastMinute Unique

**Multi-Service Platform**: Unlike traditional ride-hailing apps, LastMinute integrates transportation services with a full marketplace, allowing users to book rides and shop for goods within the same ecosystem.

**Comprehensive User Experience**: 
- **For Customers**: Book rides, track drivers in real-time, shop in the marketplace, and manage everything through a single app
- **For Partners (Drivers)**: Accept ride requests, manage earnings, and access partner-specific features with live location tracking
- **For Sellers**: List and sell products through the integrated marketplace with full order management

**Safety-First Approach**: 
- Emergency features with direct access to emergency services
- OTP-based verification for pickup and drop locations
- Real-time location tracking and monitoring
- Comprehensive rating and review system

**Enterprise-Grade Security**:
- AWS KMS encryption for all sensitive data
- Secure secret management
- Encrypted communication channels
- Privacy-focused design

### 🚀 Core Value Propositions

1. **Convenience**: One app for transportation and shopping needs
2. **Safety**: Advanced safety features and emergency protocols
3. **Reliability**: App resilience that maintains state across restarts
4. **Transparency**: Real-time tracking and clear communication
5. **Flexibility**: Multiple user types and service offerings
6. **Scalability**: Built for growth with modern architecture

### 🎨 User Experience Focus

LastMinute prioritizes user experience through:
- **App Resilience**: Seamless continuation of rides even after app restarts
- **Real-Time Updates**: Live ETA calculations and status updates
- **Intuitive Design**: Clean, modern interface across all platforms
- **Cross-Platform**: Consistent experience on Android, iOS, Web, and Desktop
- **Offline Capability**: Core functionality works even with poor connectivity

## 📱 Applications

### Customer App (`ui/customer/`)
- **Flutter-based mobile app** for customers to book rides
- Real-time ride tracking and ETA updates
- Emergency features and safety protocols
- Rating and review system
- Cross-platform support (Android, iOS, Web, Desktop)

### Partner App (`ui/partner/`)
- **Driver/partner mobile app** for ride management
- Live location tracking and updates
- OTP-based pickup/drop verification
- Real-time booking notifications
- Earnings and wallet management

### Marketplace App (`ui/marketplace/`)
- **E-commerce marketplace** for buying/selling goods
- Product catalog with image uploads
- Order management and cart functionality
- Seller and customer management

## 🏗️ Backend Architecture

### Django REST API (`backend/`)
- **Django-based backend** with multiple apps:
  - `bookings/` - Ride booking and management
  - `users/` - Customer, partner, and seller management
  - `vehicles/` - Vehicle type and management
  - `marketplace/` - E-commerce functionality
  - `wallet/` - Payment and wallet management

### Key Features
- **WebSocket Support** - Real-time communication with Django Channels
- **AWS Integration** - S3 for file storage, SNS for notifications
- **KMS Security** - Encrypted secret management
- **Docker Deployment** - Containerized deployment with ECS
- **GraphQL API** - Alternative API with Graphene-Django

## 🔧 Technology Stack

### Backend
- **Django** - Web framework
- **Django REST Framework** - API development
- **Django Channels** - WebSocket support
- **PostgreSQL** - Primary database
- **Redis** - Caching and session storage
- **AWS S3** - File storage
- **AWS SNS** - Push notifications
- **AWS KMS** - Secret encryption

### Frontend
- **Flutter** - Cross-platform mobile development
- **Dart** - Programming language
- **Google Maps** - Location services
- **WebSocket** - Real-time communication

### DevOps
- **Docker** - Containerization
- **AWS ECS** - Container orchestration
- **AWS KMS** - Secret management
- **GitHub Actions** - CI/CD pipeline

## 🚀 Key Features

### Ride Management
- Real-time driver assignment and tracking
- ETA calculations and distance tracking
- OTP-based pickup/drop verification
- Emergency features and safety protocols
- Rating and review system

### App Resilience
- **State persistence** across app restarts
- **Smart navigation** to correct screens
- **Auto-cleanup** of stale states
- **Cross-platform support** for all apps

### Security
- **AWS KMS encryption** for all secrets
- **Secure environment variable** management
- **OTP verification** for ride security
- **Emergency reporting** and logging

### Marketplace
- Product catalog with image uploads
- Order management and cart functionality
- Seller and customer management
- Payment integration

## 📚 Documentation

### Core Documentation
- **[App Resilience Features](APP_RESILIENCE_FEATURES.md)** - How apps handle closures and restarts
- **[Ride Experience Enhancements](RIDE_EXPERIENCE_ENHANCEMENTS.md)** - User experience improvements
- **[AWS KMS Setup](AWS_KMS_SETUP.md)** - Secure secret management guide
- **[Secrets Setup](SECRETS_SETUP.md)** - Environment variable configuration

### Project Structure
```
LastMinute/
├── backend/                 # Django backend
│   ├── bookings/           # Ride booking management
│   ├── users/             # User management (customers, partners, sellers)
│   ├── vehicles/          # Vehicle management
│   ├── marketplace/       # E-commerce functionality
│   ├── wallet/           # Payment and wallet management
│   └── main/             # Django project settings
├── ui/                   # Flutter applications
│   ├── customer/         # Customer mobile app
│   ├── partner/          # Partner/driver mobile app
│   └── marketplace/      # Marketplace mobile app
└── docs/                 # Documentation files
```

## 🛠️ Setup and Installation

### Prerequisites
- Python 3.8+
- Flutter SDK
- PostgreSQL
- Redis
- AWS CLI (for deployment)

### Backend Setup
```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Flutter Apps Setup
```bash
# Customer App
cd ui/customer
flutter pub get
flutter run

# Partner App
cd ui/partner
flutter pub get
flutter run

# Marketplace App
cd ui/marketplace
flutter pub get
flutter run
```

### Environment Configuration
1. Copy `.env.example` to `.env`
2. Configure your environment variables (see [Secrets Setup](SECRETS_SETUP.md))
3. Set up AWS KMS for production (see [AWS KMS Setup](AWS_KMS_SETUP.md))

## 🚀 Deployment

### Docker Deployment
```bash
# Build and run with Docker
docker-compose up --build
```

### AWS ECS Deployment
```bash
# Deploy to ECS
cd backend
./deploy.sh
```

## 📊 Features Overview

### Customer Experience
- ✅ Easy ride booking with real-time tracking
- ✅ Emergency features for safety
- ✅ Rating and review system
- ✅ App resilience across restarts
- ✅ Real-time ETA updates

### Partner Experience
- ✅ Real-time booking notifications
- ✅ Live location tracking
- ✅ OTP verification system
- ✅ Earnings management
- ✅ App state persistence

### Marketplace Experience
- ✅ Product catalog management
- ✅ Order processing
- ✅ Image uploads
- ✅ Seller dashboard

### Technical Features
- ✅ Real-time WebSocket communication
- ✅ AWS KMS encrypted secrets
- ✅ Docker containerization
- ✅ Cross-platform Flutter apps
- ✅ RESTful and GraphQL APIs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is private and proprietary.

## 📞 Support

For support and questions, please contact the development team.

---

**LastMinute** - Making transportation and commerce seamless and secure.