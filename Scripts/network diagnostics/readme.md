**Usage Instructions:**

The diagnostic tools in this repository are designed to help troubleshoot common issues related to network connectivity and application management. Here are some best use cases for these tools:

### Network Diagnostic Script

* **Collecting Network Health Information**: Run the script on an endpoint to gather detailed information about its current network configuration, including IP addresses, subnet masks, default gateways, DNS servers, and more.
* **Troubleshooting Connectivity Issues**: Use the script to identify potential causes of connectivity problems, such as duplicate IP addresses, incorrect routing tables or mismatched subnet masks.
* **Network Configuration Validation**: Validate network configurations across multiple endpoints to ensure consistency and detect potential issues.

To use the script:

1. Save the script to Jamf Pro and add to a Policy to run on a local machine or endpoint.
2. The script runs with administrator privileges.
3. Select the desired application and main destination host of that application for analysis.
4. Review the generated report for detailed network information.
5. Use the collected data to identify and troubleshoot connectivity issues.

### Kill Application Script

* **Corrupt or Damaged Application Removal**: Utilize this tool to stop and remove applications that are no longer running correctly or have become corrupted, freeing up resources on an endpoint system.
* **Resource Optimization**: Stop unnecessary or resource-intensive applications to improve overall system performance.
* **Application Management**: Use the tool as part of a larger application management strategy to maintain a healthy and efficient computing environment.
* **DNS Cache flush**: Clearing the DNS cache can help fix network-related problems that apps may encounter. Updating the stored information about domain names and their corresponding IP addresses can resolve connectivity issues.

To use the script:

1. Save the script to Jamf Pro and add to a Policy to run on a local machine or endpoint.
2. The script runs with administrator privileges.
3. Select the desired application to stop and remove.
4. Script will kill all process ID's associated with that application
5. Review the generated report for confirmation of successful process shutdown.

**Additional Tips**

* Always review the generated reports from these tools to ensure accurate information is being collected and processed.
* Use these tools in conjunction with other diagnostic tools and best practices to achieve comprehensive system health insights.
* Regularly update the scripts and tools to maintain compatibility with evolving operating systems and technologies.
