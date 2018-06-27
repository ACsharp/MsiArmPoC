
using System.IO;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs.Host;
using Newtonsoft.Json;
using Microsoft.Azure.Services.AppAuthentication;
using Microsoft.Azure.ServiceBus;

using System.Text;
using System.Threading.Tasks;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Azure.ServiceBus.Primitives;
using System;

namespace MsiAsbSender
{
    public static class Function1
    {
        [FunctionName("Function1")]
        public static async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)]HttpRequest req, TraceWriter log)
        {
            // var azureServiceTokenProvider = new AzureServiceTokenProvider();
            //azureServiceTokenProvider.
            //string accessToken = await azureServiceTokenProvider.GetAccessTokenAsync("https://management.azure.com/");
            //// OR
            //var kv = new KeyVaultClient(new KeyVaultClient.AuthenticationCallback(azureServiceTokenProvider.KeyVaultTokenCallback));

            try
            {

                var tokenProvider = TokenProvider.CreateManagedServiceIdentityTokenProvider();
                var queueClient = new QueueClient("sb://asb-msitest-asos3.servicebus.windows.net", "myqueue", tokenProvider, TransportType.Amqp);

                var message = new Message(Encoding.UTF8.GetBytes("My message"));
                await queueClient.SendAsync(message);

                await queueClient.CloseAsync();
                return (IActionResult)new OkObjectResult("Message sent");
            }
            catch (Exception ex)
            {
                log.Error(ex.ToString(), ex);
                return (IActionResult)new BadRequestObjectResult(ex.ToString());

            }





        }
    }
}
