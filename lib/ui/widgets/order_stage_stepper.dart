import 'package:flutter/material.dart';

class OrderStageStepper extends StatelessWidget {
  final List<String> stages;
  final String currentStage;
  final Function(String nextStage) onStageChange;

  const OrderStageStepper({
    super.key,
    required this.stages,
    required this.currentStage,
    required this.onStageChange,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        stages.indexWhere((s) => s.toLowerCase() == currentStage.toLowerCase());

    if (currentStage == "Rejected" || currentStage == "Cancelled") {
      return const SizedBox.shrink(); // Don't show stepper for Rejected/Cancelled
    }

    // Check if current stage is "Accepted" or later
    if (currentStage == "Accepted") {
      // Only allow next stage to be changed
      //return _buildStepper(context, currentIndex);
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(stages.length, (index) {
            final stage = stages[index];
            final isCurrent = index == currentIndex;
            final isDone = index < currentIndex;
            final isNext = index == currentIndex + 1;

            final color = isDone ? Colors.green : Colors.white;
            final textColor = Colors.green;

            return Expanded(
              child: GestureDetector(
                onTap: isNext
                    ? () => onStageChange(stage)
                    : null, // Only allow next stage
                child: Column(
                  children: [
                    Container(
                      width: 48, // Total size including border
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green, // Border color
                          width: 1.0, // Border width
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: index <= currentIndex  
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.green)
                            : Text(
                                (index + 1).toString(),
                                style: const TextStyle(color: Colors.green),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Text(
          "Only next stage is allowed. Previous stages are locked.",
          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
        )
      ],
    );
  }
}
