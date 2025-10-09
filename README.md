# LastMinute 🚗

A comprehensive multi-platform transportation and marketplace application built with Django and Flutter.

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