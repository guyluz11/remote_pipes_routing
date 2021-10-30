import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:remote_pipes_router/domain/hub_client/remote_pipes_client.dart';
import 'package:remote_pipes_router/infrastructure/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbgrpc.dart';
import 'package:remote_pipes_router/utils.dart';

/// This class get what to execute straight from the grpc request,
class SmartServerU extends CbjHubServiceBase {
  @override
  Stream<RequestsAndStatusFromHub> clientTransferDevices(
    ServiceCall call,
    Stream<ClientStatusRequests> request,
  ) async* {
    logger.v('RegisterClient have been called');

    final Map<String, String>? a = call.clientMetadata;
    final String fullUrl = a![':authority']!;

    final String? domainName;

    if (fullUrl.contains(':')) {
      domainName = fullUrl.substring(0, fullUrl.indexOf(':'));
    } else if (fullUrl.contains('\\')) {
      domainName = fullUrl.substring(0, fullUrl.indexOf('\\'));
    } else {
      logger.e('Error in the url processing of $fullUrl');
      return;
    }

    try {
      final StreamController<ClientStatusRequests> clientRequests =
          StreamController<ClientStatusRequests>();

      clientRequests.addStream(request);

      final StreamController<RequestsAndStatusFromHub> hubRequests =
          StreamController<RequestsAndStatusFromHub>();
      RemotePipesClient.createClientStreamWithRemotePipes(
        domainName,
        50051,
        hubRequests,
        clientRequests,
      );

      yield* hubRequests.stream.handleError((error) {
        if (error is GrpcError && error.code == 1) {
          logger.v('Client have disconnected');
        } else {
          logger.e('Client stream error: $error');
        }
      });
    } catch (e) {
      logger.e('Client Client error $e');
    }
  }

  @override
  Stream<ClientStatusRequests> hubTransferDevices(
    ServiceCall call,
    Stream<RequestsAndStatusFromHub> request,
  ) async* {
    logger.v('RegisterHub have been called');

    final Map<String, String>? a = call.clientMetadata;
    final String fullUrl = a![':authority']!;

    final String? domainName;

    if (fullUrl.contains(':')) {
      domainName = fullUrl.substring(0, fullUrl.indexOf(':'));
    } else if (fullUrl.contains('\\')) {
      domainName = fullUrl.substring(0, fullUrl.indexOf('\\'));
    } else {
      logger.e('Error in the url processing of $fullUrl');
      return;
    }

    logger.v('RegisterHub have been called');

    try {
      final StreamController<RequestsAndStatusFromHub> hubRequests =
          StreamController<RequestsAndStatusFromHub>();
      hubRequests.addStream(request);

      final StreamController<ClientStatusRequests> clientRequests =
          StreamController<ClientStatusRequests>();

      RemotePipesClient.createHubStreamWithRemotePipes(
        domainName,
        50051,
        clientRequests,
        hubRequests,
      );

      yield* clientRequests.stream.handleError((error) {
        if (error is GrpcError && error.code == 1) {
          logger.v('Client have disconnected');
        } else {
          logger.e('Client stream error: $error');
        }
      });
    } catch (e) {
      logger.e('Register Hub error $e');
    }
  }

  ///  Listening to port and deciding what to do with the response
  void waitForConnection() {
    logger.v('Wait for connection');

    final SmartServerU smartServer = SmartServerU();
    smartServer.startListen(); // Will go throw the model with the
    // grpc logic and converter to objects
  }

  ///  Listening in the background to incoming connections
  Future<void> startListen() async {
    await startLocalServer();
  }

  /// Starting the local server that listen to hub and app calls
  Future startLocalServer() async {
    try {
      final server = Server([SmartServerU()]);
      await server.serve(port: 50056);
      logger.v('Server listening on port ${server.port}...');
    } catch (e) {
      logger.e('Server error $e');
    }
  }
}
