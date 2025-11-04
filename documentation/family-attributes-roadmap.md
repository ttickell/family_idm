# Family Identity Attributes Configuration

## Overview

This document outlines the recommended user attributes for a comprehensive family identity management system. These attributes extend beyond basic authentication to provide family-specific functionality, emergency preparedness, and household organization.

## Implementation Status

- ❌ **Not Started** - Phase 1 attributes need implementation
- 🎯 **Priority** - Essential for family functionality
- 📋 **Planned** - Future enhancement features

## Core Identity Attributes (✅ Implemented)

| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Status | Notes |
|---------|-------------------|---------------------|--------|-------|
| Username | username | userPrincipalName | ✅ | Primary login identifier |
| First Name | firstName | givenName | ✅ | Legal first name |
| Last Name | lastName | sn | ✅ | Family surname |
| Email | email | mail | ✅ | Primary email contact |

## Phase 1: Essential Family Attributes (🎯 Priority)

### Contact Information
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Mobile Phone | mobile | mobile | ❌ | Critical for 2FA, family communication |
| Home Phone | homePhone | homePhone | ❌ | Family landline backup |
| Work Phone | workPhone | telephoneNumber | ❌ | Business contact |

### Family Structure
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Family Role | title | title | ❌ | "Parent", "Child", "Guardian", "Grandparent" |
| Department | department | department | ✅ | Force default: "Family" |
| Manager | manager | manager | ❌ | DN of family head/guardian for hierarchy |

### Security & Access Control
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Account Type | accountType | extensionAttribute7 | ✅ | "Adult", "Child", "Guest" - Force default |
| Access Level | accessLevel | extensionAttribute8 | ❌ | "Full", "Limited", "Restricted" |
| Device Limit | deviceLimit | extensionAttribute9 | ❌ | Max concurrent authenticated devices |

## Phase 2: Personal & Emergency Information (📋 Planned)

### Personal Details
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Birthday | dateOfBirth | extensionAttribute1 | ❌ | For family calendar integration |
| Nickname | displayName | displayName | ❌ | Preferred name for family use |
| Location | physicalOffice | physicalDeliveryOfficeName | ❌ | Home office/room assignment |

### Emergency Preparedness
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Emergency Contact | emergencyContact | extensionAttribute2 | ❌ | External family contact with phone |
| Medical Info | medicalInfo | extensionAttribute3 | ❌ | Critical allergies, medical conditions |
| Blood Type | bloodType | extensionAttribute4 | ❌ | Emergency medical information |

## Phase 3: Family Management Features (📋 Future)

### Household Organization
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Allowance | allowance | extensionAttribute5 | ❌ | For children - budget tracking |
| Chores | chores | extensionAttribute6 | ❌ | Assigned household responsibilities |
| School/Work | organization | company | ❌ | School or workplace name |

### Advanced Family Features
| Purpose | Keycloak Attribute | LDAP/Samba Attribute | Required | Implementation Notes |
|---------|-------------------|---------------------|----------|---------------------|
| Bedtime | bedtime | extensionAttribute10 | ❌ | For parental controls integration |
| Screen Time Limit | screenTimeLimit | extensionAttribute11 | ❌ | Daily device usage limits |
| Pickup Authorization | pickupAuth | extensionAttribute12 | ❌ | Authorized to pick up children |

## Implementation Guidelines

### Required vs Optional Fields
- **Required fields** should have `is.mandatory.in.ldap = true`
- **Optional fields** should allow empty values
- **Force Default Value** only for organizational attributes like department

### Privacy Considerations
- **Medical information** should be encrypted or access-controlled
- **Emergency contacts** should be easily accessible to all family adults
- **Children's information** should have restricted access

### Security Model
- **Account Type** drives access control policies
- **Access Level** provides granular permissions
- **Device Limit** prevents account sharing/abuse

## CLI Implementation Template

### Discover Federation ID
```bash
LDAP_ID=$(podman exec -it keycloak-main /opt/keycloak/bin/kcadm.sh get components -r tickell | jq -r '.[] | select(.name=="Samba LDAP") | .id')
```

### Create Attribute Mapper Template
```bash
podman exec -it keycloak-main /opt/keycloak/bin/kcadm.sh create components -r tickell \
  -s name="ATTRIBUTE_NAME" \
  -s providerId="user-attribute-ldap-mapper" \
  -s providerType="org.keycloak.storage.ldap.mappers.LDAPStorageMapper" \
  -s parentId="$LDAP_ID" \
  -s 'config."ldap.attribute"=["LDAP_ATTRIBUTE"]' \
  -s 'config."user.model.attribute"=["KEYCLOAK_ATTRIBUTE"]' \
  -s 'config."read.only"=["false"]' \
  -s 'config."always.read.value.from.ldap"=["false"]' \
  -s 'config."is.mandatory.in.ldap"=["false"]'
```

### Phase 1 Implementation Commands

#### Mobile Phone
```bash
podman exec -it keycloak-main /opt/keycloak/bin/kcadm.sh create components -r tickell \
  -s name="Mobile Phone" \
  -s providerId="user-attribute-ldap-mapper" \
  -s providerType="org.keycloak.storage.ldap.mappers.LDAPStorageMapper" \
  -s parentId="$LDAP_ID" \
  -s 'config."ldap.attribute"=["mobile"]' \
  -s 'config."user.model.attribute"=["mobile"]' \
  -s 'config."read.only"=["false"]' \
  -s 'config."always.read.value.from.ldap"=["false"]' \
  -s 'config."is.mandatory.in.ldap"=["false"]'
```

#### Family Role
```bash
podman exec -it keycloak-main /opt/keycloak/bin/kcadm.sh create components -r tickell \
  -s name="Family Role" \
  -s providerId="user-attribute-ldap-mapper" \
  -s providerType="org.keycloak.storage.ldap.mappers.LDAPStorageMapper" \
  -s parentId="$LDAP_ID" \
  -s 'config."ldap.attribute"=["title"]' \
  -s 'config."user.model.attribute"=["title"]' \
  -s 'config."read.only"=["false"]' \
  -s 'config."always.read.value.from.ldap"=["false"]' \
  -s 'config."is.mandatory.in.ldap"=["false"]'
```

#### Account Type (with default value)
```bash
podman exec -it keycloak-main /opt/keycloak/bin/kcadm.sh create components -r tickell \
  -s name="Account Type" \
  -s providerId="user-attribute-ldap-mapper" \
  -s providerType="org.keycloak.storage.ldap.mappers.LDAPStorageMapper" \
  -s parentId="$LDAP_ID" \
  -s 'config."ldap.attribute"=["extensionAttribute7"]' \
  -s 'config."user.model.attribute"=["accountType"]' \
  -s 'config."read.only"=["false"]' \
  -s 'config."always.read.value.from.ldap"=["false"]' \
  -s 'config."is.mandatory.in.ldap"=["true"]' \
  -s 'config."attribute.default.value"=["Adult"]' \
  -s 'config."always.read.value.from.ldap"=["true"]'
```

## Integration Opportunities

### Home Automation
- **Location attributes** for presence detection
- **Bedtime/Screen time** for parental controls
- **Access levels** for smart home permissions

### Family Calendar
- **Birthday attributes** for automatic calendar events
- **School/Work schedules** for family coordination
- **Emergency contacts** for event notifications

### Financial Management
- **Allowance tracking** integration with family budgeting
- **Account types** for spending permissions
- **Device limits** for subscription management

## Next Steps

1. **Implement Phase 1** essential attributes first
2. **Test user experience** with family members
3. **Gather feedback** on usefulness and privacy concerns
4. **Iterate on Phase 2** based on actual family needs
5. **Integrate with family services** as attributes become available

## Security Considerations

- Regular **attribute cleanup** - remove unused extension attributes
- **Access control** for sensitive medical/emergency information  
- **Audit trails** for attribute changes, especially for children
- **Data retention** policies for family member lifecycle
- **Privacy controls** for what family members can see about each other