import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from matplotlib.collections import PatchCollection

class FractalAntenna:
    """
    A class to generate and visualize various fractal antenna patterns.
    """
    def __init__(self):
        self.patterns = {}
        
    def koch_curve(self, start, end, iterations):
        """
        Generate points for a Koch curve fractal.
        
        Parameters:
        start: Starting point coordinates
        end: Ending point coordinates
        iterations: Number of fractal iterations
        """
        if iterations == 0:
            return [start, end]
            
        # Calculate the basic vectors and points for the Koch curve
        dx = end[0] - start[0]
        dy = end[1] - start[1]
        
        # Calculate intermediate points
        p1 = (start[0] + dx/3, start[1] + dy/3)
        p3 = (start[0] + 2*dx/3, start[1] + 2*dy/3)
        
        # Calculate the peak point using 60-degree rotation
        vec = np.array([dx/3, dy/3])
        rot = np.array([[np.cos(np.pi/3), -np.sin(np.pi/3)],
                       [np.sin(np.pi/3), np.cos(np.pi/3)]])
        peak_vec = rot.dot(vec)
        p2 = (p1[0] + peak_vec[0], p1[1] + peak_vec[1])
        
        # Recursive calls for each segment
        curve = (self.koch_curve(start, p1, iterations-1) +
                self.koch_curve(p1, p2, iterations-1) +
                self.koch_curve(p2, p3, iterations-1) +
                self.koch_curve(p3, end, iterations-1))
        
        return curve[:-1] + [end]

    def sierpinski_gasket(self, points, iterations):
        """
        Generate points for a Sierpinski gasket fractal.
        
        Parameters:
        points: Initial triangle vertices
        iterations: Number of fractal iterations
        """
        if iterations == 0:
            return [points]
            
        # Calculate midpoints
        p1, p2, p3 = points
        m1 = ((p1[0] + p2[0])/2, (p1[1] + p2[1])/2)
        m2 = ((p2[0] + p3[0])/2, (p2[1] + p3[1])/2)
        m3 = ((p3[0] + p1[0])/2, (p3[1] + p1[1])/2)
        
        # Recursive calls for each subtriangle
        triangles = (self.sierpinski_gasket([p1, m1, m3], iterations-1) +
                    self.sierpinski_gasket([m1, p2, m2], iterations-1) +
                    self.sierpinski_gasket([m3, m2, p3], iterations-1))
        
        return triangles

    def minkowski_island(self, start, end, iterations):
        """
        Generate points for a Minkowski island fractal.
        
        Parameters:
        start: Starting point coordinates
        end: Ending point coordinates
        iterations: Number of fractal iterations
        """
        if iterations == 0:
            return [start, end]
            
        dx = (end[0] - start[0]) / 4
        dy = (end[1] - start[1]) / 4
        
        # Calculate the eight points for Minkowski curve
        points = [
            start,
            (start[0] + dx, start[1] + dy),
            (start[0] + dx, start[1] + 2*dy),
            (start[0] + 2*dx, start[1] + 2*dy),
            (start[0] + 2*dx, start[1] + dy),
            (start[0] + 3*dx, start[1] + dy),
            (start[0] + 3*dx, start[1]),
            end
        ]
        
        # Recursive generation
        curve = []
        for i in range(len(points)-1):
            curve.extend(self.minkowski_island(points[i], points[i+1], iterations-1)[:-1])
        curve.append(end)
        
        return curve

    def plot_koch_snowflake(self, iterations=4, size=1):
        """Plot a Koch snowflake antenna pattern."""
        # Initialize the three sides of the snowflake
        height = size * np.sqrt(3)/2
        points = [
            (0, height),
            (size/2, -height/3),
            (-size/2, -height/3)
        ]
        
        # Generate the three sides
        curves = []
        for i in range(3):
            start = points[i]
            end = points[(i+1)%3]
            curves.extend(self.koch_curve(start, end, iterations)[:-1])
        
        # Plot the result
        plt.figure(figsize=(10, 10))
        x_coords = [p[0] for p in curves]
        y_coords = [p[1] for p in curves]
        plt.plot(x_coords + [x_coords[0]], y_coords + [y_coords[0]], 'b-')
        plt.title(f'Koch Snowflake Antenna (Iterations: {iterations})')
        plt.axis('equal')
        plt.grid(True)
        plt.show()

    def plot_sierpinski(self, iterations=5, size=1):
        """Plot a Sierpinski gasket antenna pattern."""
        # Initial triangle
        height = size * np.sqrt(3)/2
        points = [
            (0, height),
            (size/2, -height/3),
            (-size/2, -height/3)
        ]
        
        # Generate triangles
        triangles = self.sierpinski_gasket(points, iterations)
        
        # Plot the result
        plt.figure(figsize=(10, 10))
        patches = []
        for triangle in triangles:
            patches.append(Polygon(triangle))
        
        collection = PatchCollection(patches, facecolor='blue', edgecolor='black')
        plt.gca().add_collection(collection)
        plt.title(f'Sierpinski Gasket Antenna (Iterations: {iterations})')
        plt.axis('equal')
        plt.xlim(-size/1.5, size/1.5)
        plt.ylim(-size/1.5, size/1.5)
        plt.grid(True)
        plt.show()

    def simulate_radiation_pattern(self, points, frequency=2.4e9):
        """
        Simulate a basic radiation pattern for the antenna.
        This is a simplified simulation for visualization purposes.
        
        Parameters:
        points: Array of antenna segment coordinates
        frequency: Operating frequency in Hz
        """
        # Calculate wavelength
        c = 3e8  # speed of light
        wavelength = c / frequency
        
        # Calculate radiation pattern
        theta = np.linspace(0, 2*np.pi, 360)
        pattern = np.zeros_like(theta)
        
        # Simple radiation pattern calculation
        for i, angle in enumerate(theta):
            field = 0
            for j in range(len(points)-1):
                # Calculate contribution from each segment
                dx = points[j+1][0] - points[j][0]
                dy = points[j+1][1] - points[j][1]
                length = np.sqrt(dx**2 + dy**2)
                
                # Simplified current distribution
                current = np.exp(-1j * 2*np.pi * length/wavelength)
                
                # Add contribution to far-field pattern
                field += current * length * np.exp(1j * 2*np.pi/wavelength * 
                        (points[j][0]*np.cos(angle) + points[j][1]*np.sin(angle)))
            
            pattern[i] = np.abs(field)
        
        # Normalize pattern
        pattern = pattern / np.max(pattern)
        
        # Plot radiation pattern
        plt.figure(figsize=(10, 10))
        ax = plt.subplot(111, projection='polar')
        ax.plot(theta, pattern)
        ax.set_title('Simulated Radiation Pattern')
        plt.show()

# Example usage
if __name__ == "__main__":
    antenna = FractalAntenna()
    
    # Generate and plot Koch snowflake antenna
    print("Generating Koch Snowflake Antenna...")
    antenna.plot_koch_snowflake(iterations=4)
    
    # Generate and plot Sierpinski gasket antenna
    print("Generating Sierpinski Gasket Antenna...")
    antenna.plot_sierpinski(iterations=5)
    
    # Generate points for radiation pattern simulation
    koch_points = antenna.koch_curve((0,0), (1,0), 3)
    print("Simulating Radiation Pattern...")
    antenna.simulate_radiation_pattern(koch_points)
