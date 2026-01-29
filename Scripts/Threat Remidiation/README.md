
# Incident Response Process for User Devices using Jamf Pro and Jamf Protect

This document outlines the incident response process for managing security incidents involving user devices within an organization.

## Table of Contents
1. [Overview](#overview)
2. [Incident Categorization and Response Procedures](#incident-categorization-and-response-procedures)
	* Low Severity Incidents
	* Medium Severity Incidents
	* High Severity Incidents
3. [Importance of Effective Incident Response](#importance-of-effective-incident-response)
4. [Continuous Improvement](#continuous-improvement)

## Overview

This document provides a comprehensive guide to managing security incidents involving user devices within an organization using Jamf Pro and Jamf Protect.

### Features

* Categorization of incidents into low, medium, and high severity
* Detailed response procedures for each level of severity
* Alert generation, logging, user notifications, and remediation actions
* Emphasis on effective incident response to minimize security breaches and protect sensitive data
* Recommendations for continuous improvement to enhance organizational resilience

## Incident Categorization and Response Procedures

This section details the categorization and response procedures for incidents involving user devices.

### Low Severity Incidents

* Definition: Minor incidents with limited impact on the organization's security posture.
* Response Procedure:
	+ Alert generation and logging
	+ User notification and remediation actions
	+ Review of incident response plan to identify areas for improvement

### Medium Severity Incidents

* Definition: Moderate incidents with potential impact on the organization's security posture.
* Response Procedure:
	+ Enhanced alert generation, logging, and user notifications
	+ Remediation actions and containment procedures
	+ Review of incident response plan and identification of areas for improvement
 	+ Files less that 24 hrs will be moved to trash to enforce the removal of unauthorized applications and their installers

### High Severity Incidents

* Definition: Critical incidents with significant impact on the organization's security posture.
* Response Procedure:
	+ Immediate alert generation and notification of administrators
	+ Containment, remediation, and recovery procedures
	+ Review of incident response plan, identification of areas for improvement, and implementation of corrective actions
* Network Isolation:
	+ Network firewall modified and isolates the endpoint with custom rules
 	+ Hosts file is backed up, replaced and rebuilt dynamically from a list of required hostnames using builtin lookup tools

## Importance of Effective Incident Response

Effective incident response is crucial to minimizing security breaches, protecting sensitive data, and ensuring compliance with regulations.

## Continuous Improvement

Continuous improvement of the incident response plan is recommended to enhance organizational resilience against future security challenges. Relevant resources and controls are provided to support the incident response efforts.

### Resources

* [Jamf Pro Documentation](https://www.jamf.com/docs/pro)
* [Jamf Protect Documentation](https://www.jamf.com/docs/protect)

### Controls

* Implement incident categorization and response procedures
* Conduct regular review of incident response plan
* Provide training on incident response to relevant personnel
* Continuously monitor and improve the incident response process
